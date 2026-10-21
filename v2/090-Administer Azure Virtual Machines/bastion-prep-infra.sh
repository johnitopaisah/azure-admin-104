#!/usr/bin/env bash
# Remote access / Bastion lab prep - Azure CLI version of bastion-prep-infra.ps1
# Usage: ./bastion-prep-infra.sh        (resource group: rg-remoteaccess-<yyyyMMdd>)
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./bastion-prep-infra.sh)
RG="${RG:-rg-remoteaccess-$(date +%Y%m%d)}"
REGION="${REGION:-eastus}"
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"                #Linux VM
WIN_VM_SIZE="${WIN_VM_SIZE:-Standard_D2s_v3}"     #Windows VM
WIN_IMAGE="MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest"

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }

#Create RG
info "Creating resource group $RG"
az group create -n "$RG" -l "$REGION" -o none

#########-----Create resources---------######

info "Creating vnet-remoteaccess with windows and linux subnets"
az network vnet create -g "$RG" -l "$REGION" -n vnet-remoteaccess \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name windows --subnet-prefixes 10.0.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name vnet-remoteaccess -n linux --address-prefixes 10.0.2.0/24 -o none

info "Creating Windows VM"
az vm create -g "$RG" -l "$REGION" -n win-ra-vm \
  --size "$WIN_VM_SIZE" --image "$WIN_IMAGE" \
  --vnet-name vnet-remoteaccess --subnet windows --nsg windows-nsg \
  --public-ip-sku Standard \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" \
  --only-show-errors -o none

info "Creating Linux VM"
az vm create -g "$RG" -l "$REGION" -n linux-ra-vm \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name vnet-remoteaccess --subnet linux --nsg linux-nsg \
  --public-ip-sku Standard \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#Output
ok "Deployment completed!"
for vm in win-ra-vm linux-ra-vm; do
  echo "$vm public IP : $(az vm show -d -g "$RG" -n "$vm" --query publicIps -o tsv)"
done
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
