#!/usr/bin/env bash
# VNet peering lab prep - Azure CLI version of peering-pref-infra.ps1
# Usage: ./peering-pref-infra.sh        (resource group: rg-vnet-peering-<yyyyMMdd>)
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./peering-pref-infra.sh)
RG="${RG:-rg-vnet-peering-$(date +%Y%m%d)}"
REGION="${REGION:-eastus}"                     #region for the RG and vm-eus
SECONDARY_REGION="${SECONDARY_REGION:-westus}" #region for vm-wus
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }

#Create RG
info "Creating resource group $RG"
az group create -n "$RG" -l "$REGION" -o none

#Each VM creates its own VNet (vnet-eus / vnet-wus) and opens port 22
info "Creating EUS VM"
az vm create -g "$RG" -l "$REGION" -n vm-eus \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name vnet-eus --vnet-address-prefix 192.168.0.0/24 \
  --subnet default --subnet-address-prefix 192.168.0.0/24 \
  --public-ip-address eus-vm-pip --public-ip-sku Standard --nsg-rule SSH \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

info "Creating WUS VM"
az vm create -g "$RG" -l "$SECONDARY_REGION" -n vm-wus \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name vnet-wus --vnet-address-prefix 192.168.1.0/24 \
  --subnet default --subnet-address-prefix 192.168.1.0/24 \
  --public-ip-address wus-vm-pip --public-ip-sku Standard --nsg-rule SSH \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#Output
ok "Deployment completed!"
for vm in vm-eus vm-wus; do
  echo "$vm public IP : $(az vm show -d -g "$RG" -n "$vm" --query publicIps -o tsv)  private IP : $(az vm show -d -g "$RG" -n "$vm" --query privateIps -o tsv)"
done
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
