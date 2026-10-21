#!/usr/bin/env bash
# Application Gateway lab prep - Azure CLI version of appgw-prep-infra.ps1
# Usage: ./appgw-prep-infra.sh          (resource group: rg-appgw-<yyyyMMdd>)
# Creates 6 pool VMs (green/red/blue x2) + a jumpbox = 7 vCPUs with the default size.
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./appgw-prep-infra.sh)
RG="${RG:-rg-appgw-$(date +%Y%m%d)}"
REGION="${REGION:-eastus}"
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
POOL_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
SUFFIX="$(printf '%04x%04x' $RANDOM $RANDOM)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Writes a first-boot script that installs Apache with a colored page.
#Replaces the jumpbox.sh custom script (which SSH'd into each VM from the jumpbox).
#Args: color vm-number [subfolder]  -> red/blue also get /red/red.html, /blue/blue.html for path-based routing
web_init() {
  local file="$WORK_DIR/$1-$2.sh"
  cat >"$file" <<EOF
#!/bin/bash
apt-get -o DPkg::Lock::Timeout=300 update -y
apt-get -o DPkg::Lock::Timeout=300 install -y apache2
cat > /var/www/html/index.html <<'HTML'
<html>
  <body style="background-color:$1;">
    <h1 style="color:white;">Hi from $1-$2</h1>
  </body>
</html>
HTML
EOF
  if [ -n "${3:-}" ]; then
    echo "mkdir -p /var/www/html/$3 && cp /var/www/html/index.html /var/www/html/$3/$3.html" >>"$file"
  fi
  echo "systemctl enable --now apache2" >>"$file"
  echo "$file"
}

#Creates two pool servers for a color in <color>Subnet. Args: color
deploy_pool_servers() {
  local color="$1" subfolder="" i
  if [ "$color" != "green" ]; then subfolder="$color"; fi
  info "Creating $color color vms"
  for i in 1 2; do
    az network nic create -g "$RG" -l "$REGION" -n "$color-0$i-nic" \
      --vnet-name color-web-vnet --subnet "${color}Subnet" -o none
    info "Creating VM $color-0$i"
    az vm create -g "$RG" -l "$REGION" -n "$color-0$i" --computer-name "${color}0$i" \
      --size "$VM_SIZE" --image "$POOL_IMAGE" --nics "$color-0$i-nic" \
      --custom-data "$(web_init "$color" "$i" "$subfolder")" \
      --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
      --only-show-errors -o none
  done
}

#Prints private IPs of a color's pool servers. Args: color
find_pool_server_ip() {
  local i
  for i in 1 2; do
    echo "Private IP ($1-0$i) : $(az network nic show -g "$RG" -n "$1-0$i-nic" --query 'ipConfigurations[0].privateIPAddress' -o tsv)"
  done
}

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }

#Create RG
info "Creating resource group $RG"
az group create -n "$RG" -l "$REGION" -o none

#########-----Create resources---------######

info "Creating color-web-vnet with jumpbox, green, red and blue subnets"
az network vnet create -g "$RG" -l "$REGION" -n color-web-vnet \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name jumpboxSubnet --subnet-prefixes 10.0.0.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name color-web-vnet -n greenSubnet --address-prefixes 10.0.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name color-web-vnet -n redSubnet --address-prefixes 10.0.2.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name color-web-vnet -n blueSubnet --address-prefixes 10.0.3.0/24 -o none

#-------------------NSG--------------------------------#

info "Creating appGwNSG (allow HTTP from Internet) and attaching it to the pool subnets"
az network nsg create -g "$RG" -l "$REGION" -n appGwNSG -o none
az network nsg rule create -g "$RG" --nsg-name appGwNSG -n web-rule \
  --description "Allow HTTP" --access Allow --protocol Tcp --direction Inbound --priority 100 \
  --source-address-prefixes Internet --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 80 -o none
for subnet in greenSubnet redSubnet blueSubnet; do
  az network vnet subnet update -g "$RG" --vnet-name color-web-vnet -n "$subnet" --network-security-group appGwNSG -o none
done

#------------Creating pool servers---------------------------------------#

deploy_pool_servers green
deploy_pool_servers red
deploy_pool_servers blue

#---------------------Jumpbox------------------------------#

info "Creating jumpbox VM"
az vm create -g "$RG" -l "$REGION" -n jumpbox-vm \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name color-web-vnet --subnet jumpboxSubnet \
  --public-ip-address jumpbox-appgw-pip --public-ip-sku Standard \
  --public-ip-address-dns-name "jumpbox-appgw-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#---------------------Output------------------------------#

ok "Deployment completed! (Apache finishes installing on the pool VMs a few minutes after boot)"
echo "Jumpbox VM DNS name : $(az vm show -d -g "$RG" -n jumpbox-vm --query fqdns -o tsv)"
find_pool_server_ip green
find_pool_server_ip blue
find_pool_server_ip red
ok "Use username: $ADMIN_USER and password: $ADMIN_PASSWORD to login to any VMs"
