#!/usr/bin/env bash
# Load Balancing lab - infra only (the load balancer itself is built during the lab)
# Azure CLI version of lab-infra.ps1
# Usage: ./lab-infra.sh [resource-group-name]
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./lab-infra.sh)
REGION="${REGION:-eastus}"
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
WEB_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
SUFFIX="$(printf '%04x%04x' $RANDOM $RANDOM)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Writes a first-boot script that installs Apache with a colored page.
#Replaces the old jumpbox.sh (which SSH'd into each VM and depended on a GitHub URL).
#Args: color vm-number
web_init() {
  local file="$WORK_DIR/web-$2.sh"
  cat >"$file" <<EOF
#!/bin/bash
apt-get -o DPkg::Lock::Timeout=300 update -y
apt-get -o DPkg::Lock::Timeout=300 install -y apache2
cat > /var/www/html/index.html <<'HTML'
<html>
  <body style="background-color:$1;">
    <h1 style="color:white;">Hello from webserver-0$2</h1>
  </body>
</html>
HTML
systemctl enable --now apache2
EOF
  echo "$file"
}

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }

RG="${1:-}"
if [ -z "$RG" ]; then read -rp "(new) Resource group name: " RG; fi

#Create RG
info "Creating resource group $RG in $REGION"
az group create -n "$RG" -l "$REGION" -o none

#########-----Create resources---------######

info "Creating eus-web-dev with jumpboxSubnet and webSubnet"
az network vnet create -g "$RG" -l "$REGION" -n eus-web-dev \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name jumpboxSubnet --subnet-prefixes 10.0.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name eus-web-dev -n webSubnet --address-prefixes 10.0.2.0/24 -o none

info "Creating webNSG (allow HTTP from Internet) and attaching it to webSubnet"
az network nsg create -g "$RG" -l "$REGION" -n webNSG -o none
az network nsg rule create -g "$RG" --nsg-name webNSG -n web-rule \
  --description "Allow HTTP" --access Allow --protocol Tcp --direction Inbound --priority 100 \
  --source-address-prefixes Internet --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 80 -o none
az network vnet subnet update -g "$RG" --vnet-name eus-web-dev -n webSubnet --network-security-group webNSG -o none

info "Creating availability set"
az vm availability-set create -g "$RG" -l "$REGION" -n az-web-set \
  --platform-fault-domain-count 3 --platform-update-domain-count 3 -o none

#Web servers (no public IP): webserver-01 red, -02 green, -03 blue
i=1
for color in red green blue; do
  info "Creating VM webserver-0$i"
  az network nic create -g "$RG" -l "$REGION" -n "webserver-0$i-nic" \
    --vnet-name eus-web-dev --subnet webSubnet -o none
  az vm create -g "$RG" -l "$REGION" -n "webserver-0$i" --computer-name "webserver0$i" \
    --size "$VM_SIZE" --image "$WEB_IMAGE" --nics "webserver-0$i-nic" \
    --availability-set az-web-set \
    --custom-data "$(web_init "$color" "$i")" \
    --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
    --only-show-errors -o none
  i=$((i + 1))
done

info "Creating jumpbox VM"
az vm create -g "$RG" -l "$REGION" -n jumpbox-vm \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name eus-web-dev --subnet jumpboxSubnet \
  --public-ip-address jumpbox-pip --public-ip-sku Standard \
  --public-ip-address-dns-name "jumpbox-lb-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#Output
ok "Deployment completed! (Apache finishes installing on the web servers a few minutes after boot)"
echo "Jumpbox VM DNS name : $(az vm show -d -g "$RG" -n jumpbox-vm --query fqdns -o tsv)"
for i in 1 2 3; do
  echo "Private IP (webserver-0$i) : $(az network nic show -g "$RG" -n "webserver-0$i-nic" --query 'ipConfigurations[0].privateIPAddress' -o tsv)"
done
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
