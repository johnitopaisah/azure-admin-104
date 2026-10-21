#!/usr/bin/env bash
# NSG lab prep - Azure CLI version of nsg-prep-infra.ps1
# Usage: ./nsg-prep-infra.sh            (resource group: rg-nsg-workload-<yyyyMMdd>)
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./nsg-prep-infra.sh)
RG="${RG:-rg-nsg-workload-$(date +%Y%m%d)}"
REGION="${REGION:-eastus}"
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
SUFFIX="$(printf '%04x%04x' $RANDOM $RANDOM)"

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }

#Create RG
info "Adding resource group : $RG"
az group create -n "$RG" -l "$REGION" -o none

#########-----Create resources---------######

info "Adding workload network configuration"
az network vnet create -g "$RG" -l "$REGION" -n vnet-workloads \
  --address-prefixes 192.168.0.0/16 \
  --subnet-name snet-workload-a --subnet-prefixes 192.168.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name vnet-workloads -n snet-workload-b \
  --address-prefixes 192.168.2.0/24 -o none

for i in 1 2; do
  for w in a b; do
    vm="workload-$w-vm-$i"
    info "Creating $vm"
    az vm create -g "$RG" -l "$REGION" -n "$vm" \
      --size "$VM_SIZE" --image Ubuntu2204 \
      --vnet-name vnet-workloads --subnet "snet-workload-$w" \
      --public-ip-address "$vm-pip" --public-ip-sku Standard \
      --public-ip-address-dns-name "$vm-$SUFFIX" \
      --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
      --only-show-errors -o none
    ok "$vm FQDN : $(az vm show -d -g "$RG" -n "$vm" --query fqdns -o tsv)"
  done
done

ok "Deployment completed! Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
