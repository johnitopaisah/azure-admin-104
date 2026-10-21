#!/usr/bin/env bash
# VNet-to-VNet VPN lab infrastructure - Azure CLI version of lab-infra.ps1
# Usage: ./lab-infra.sh [resource-group-name]
# NOTE: each VPN gateway takes ~30-45 minutes. Both are created in parallel.
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./lab-infra.sh)
REGION="${REGION:-eastus}"                     #region for the RG and the "EUS" network
SECONDARY_REGION="${SECONDARY_REGION:-westus}" #region for the "WUS" network
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
GW_SKU="${GW_SKU:-VpnGw1AZ}"                   #non-AZ SKUs (VpnGw1) can no longer be created
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

#########-----Networks + VMs---------######

info "Creating eus-vnet with default and GatewaySubnet ($REGION)"
az network vnet create -g "$RG" -l "$REGION" -n eus-vnet \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name default --subnet-prefixes 10.0.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name eus-vnet -n GatewaySubnet \
  --address-prefixes 10.0.0.0/28 -o none

info "Creating wus-vnet with default and GatewaySubnet ($SECONDARY_REGION)"
az network vnet create -g "$RG" -l "$SECONDARY_REGION" -n wus-vnet \
  --address-prefixes 192.168.0.0/16 \
  --subnet-name default --subnet-prefixes 192.168.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name wus-vnet -n GatewaySubnet \
  --address-prefixes 192.168.0.0/28 -o none

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
  --vnet-name wus-vnet --subnet default \
  --public-ip-sku Standard --public-ip-address-dns-name "wus-prod-server-$SUFFIX" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#########-----VPN gateways (both build in parallel)---------######

info "Creating gateway public IPs (Standard, Static)"
az network public-ip create -g "$RG" -l "$REGION" -n pip-vpn-eus \
  --sku Standard --allocation-method Static -o none
az network public-ip create -g "$RG" -l "$SECONDARY_REGION" -n pip-vpn-wus \
  --sku Standard --allocation-method Static -o none

info "Starting VPN gateway vpngw-eus ($GW_SKU) - runs in the background"
az network vnet-gateway create -g "$RG" -l "$REGION" -n vpngw-eus \
  --vnet eus-vnet --public-ip-addresses pip-vpn-eus \
  --gateway-type Vpn --vpn-type RouteBased --sku "$GW_SKU" --no-wait -o none

info "Starting VPN gateway vpngw-wus ($GW_SKU) - runs in the background"
az network vnet-gateway create -g "$RG" -l "$SECONDARY_REGION" -n vpngw-wus \
  --vnet wus-vnet --public-ip-addresses pip-vpn-wus \
  --gateway-type Vpn --vpn-type RouteBased --sku "$GW_SKU" --no-wait -o none

info "Waiting for both VPN gateways to finish (this can take 30-45 minutes)..."
az network vnet-gateway wait -g "$RG" -n vpngw-eus --created
az network vnet-gateway wait -g "$RG" -n vpngw-wus --created

#Output
ok "Deployment completed!"
echo "East US VM DNS name : $(az vm show -d -g "$RG" -n eus-prod-server --query fqdns -o tsv)"
echo "West US VM DNS name : $(az vm show -d -g "$RG" -n wus-prod-server --query fqdns -o tsv)"
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
