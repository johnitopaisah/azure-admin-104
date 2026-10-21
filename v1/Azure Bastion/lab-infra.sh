#!/usr/bin/env bash
# Azure Bastion lab infrastructure - Azure CLI version of lab-infra.ps1
# Usage: ./lab-infra.sh [resource-group-name]
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./lab-infra.sh)
REGION="${REGION:-eastus}"
ADMIN_USER="${ADMIN_USER:-kodekloud}"          #username for the VMs
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #password for the VMs (az CLI requires 12+ characters)
LINUX_VM_SIZE="${LINUX_VM_SIZE:-Standard_B1s}"
WIN_VM_SIZE="${WIN_VM_SIZE:-Standard_D2s_v3}"
SUFFIX="$(printf '%04x%04x' $RANDOM $RANDOM)"     #keeps DNS labels globally unique

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }

RG="${1:-}"
if [ -z "$RG" ]; then read -rp "(new) Resource Group Name: " RG; fi

#Create RG
info "Creating resource group $RG in $REGION"
az group create -n "$RG" -l "$REGION" -o none

#########-----Create resources---------######

#Creating vnet and VMs
info "Creating prod-eus-vnet with privateSubnet"
az network vnet create -g "$RG" -l "$REGION" -n prod-eus-vnet \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name privateSubnet --subnet-prefixes 10.0.0.0/24 -o none

info "Creating Linux VM"
az vm create -g "$RG" -l "$REGION" -n linux-prod-server \
  --size "$LINUX_VM_SIZE" --image Ubuntu2204 \
  --vnet-name prod-eus-vnet --subnet privateSubnet \
  --public-ip-sku Standard --public-ip-address-dns-name "linux-prod-server-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

info "Creating Windows VM"
az vm create -g "$RG" -l "$REGION" -n win-prod-server \
  --size "$WIN_VM_SIZE" --image Win2022Datacenter \
  --vnet-name prod-eus-vnet --subnet privateSubnet \
  --public-ip-sku Standard --public-ip-address-dns-name "win-prod-server-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" \
  --only-show-errors -o none

#Output
ok "Deployment completed!"
echo "Linux VM DNS name   : $(az vm show -d -g "$RG" -n linux-prod-server --query fqdns -o tsv)"
echo "Windows VM DNS name : $(az vm show -d -g "$RG" -n win-prod-server --query fqdns -o tsv)"
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
