#!/usr/bin/env bash
# VNet Peering lab infrastructure - Azure CLI version of lab-infra.ps1
# Usage: ./lab-infra.sh [resource-group-name]
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./lab-infra.sh)
REGION="${REGION:-eastus}"                     #region for the RG and the "EUS" network
SECONDARY_REGION="${SECONDARY_REGION:-westus}" #region for the "WUS" network
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
SUFFIX="$(printf '%04x%04x' $RANDOM $RANDOM)"

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

info "Creating eus-vnet ($REGION)"
az network vnet create -g "$RG" -l "$REGION" -n eus-vnet \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name default --subnet-prefixes 10.0.0.0/24 -o none

info "Creating wus-vnet ($SECONDARY_REGION)"
az network vnet create -g "$RG" -l "$SECONDARY_REGION" -n wus-vnet \
  --address-prefixes 192.168.0.0/16 \
  --subnet-name privateSubnet --subnet-prefixes 192.168.1.0/24 -o none

info "Creating East US VM"
az vm create -g "$RG" -l "$REGION" -n eus-prod-server \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name eus-vnet --subnet default \
  --public-ip-address eus-vm-pip --public-ip-sku Standard \
  --public-ip-address-dns-name "eus-prod-server-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

info "Creating West US VM"
az vm create -g "$RG" -l "$SECONDARY_REGION" -n wus-prod-server \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name wus-vnet --subnet privateSubnet \
  --public-ip-sku Standard --public-ip-address-dns-name "wus-prod-server-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#Output
ok "Deployment completed!"
echo "East US VM DNS name : $(az vm show -d -g "$RG" -n eus-prod-server --query fqdns -o tsv)"
echo "West US VM DNS name : $(az vm show -d -g "$RG" -n wus-prod-server --query fqdns -o tsv)"
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
