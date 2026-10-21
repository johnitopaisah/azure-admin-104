#!/usr/bin/env bash
# Service endpoints lab prep - Azure CLI version of service-endpoints-prep-infra.ps1
# Usage: ./service-endpoints-prep-infra.sh   (resource group: rg-se-workload-<yyyyMMdd>)
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./service-endpoints-prep-infra.sh)
RG="${RG:-rg-se-workload-$(date +%Y%m%d)}"
REGION="${REGION:-eastus}"
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
STORAGE_NAME="st${RANDOM}$(date +%Y%m%d)"        #must be globally unique, lowercase, 3-24 chars

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }
az storage account create --help >/dev/null 2>&1 || {
  echo "'az storage' commands are broken on this machine (usually an outdated storage-preview extension)." >&2
  echo "Fix with: az extension remove --name storage-preview" >&2; exit 1; }

#Create RG (the PowerShell version forgot this step)
info "Creating resource group $RG"
az group create -n "$RG" -l "$REGION" -o none

#Create VM (also creates vnet-01 with the 'default' subnet)
info "Creating VM"
az vm create -g "$RG" -l "$REGION" -n vm-01 \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name vnet-01 --vnet-address-prefix 192.168.0.0/16 \
  --subnet default --subnet-address-prefix 192.168.1.0/24 \
  --public-ip-address vm-01-pip --public-ip-sku Standard \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none
ok "vm-01 public IP : $(az vm show -d -g "$RG" -n vm-01 --query publicIps -o tsv)"

#Create storage
info "Creating storage account $STORAGE_NAME"
az storage account create -g "$RG" -l "$REGION" -n "$STORAGE_NAME" \
  --kind StorageV2 --sku Standard_LRS --allow-blob-public-access true -o none

ok "Deployment completed! Storage account: $STORAGE_NAME"
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
