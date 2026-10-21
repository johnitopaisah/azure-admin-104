#!/usr/bin/env bash
# Gateway Transit (hub & spoke) lab infrastructure - Azure CLI version of lab-infra.ps1
# Usage: ./lab-infra.sh [resource-group-name]
# NOTE: the hub VPN gateway takes ~30-45 minutes. It builds while the spokes are created.
set -euo pipefail

#Variables (override with environment variables, e.g. REGION=westeurope ./lab-infra.sh)
REGION="${REGION:-eastus}"                     #region for the RG, hub and spoke-1
SECONDARY_REGION="${SECONDARY_REGION:-westus}" #region for spoke-2
ADMIN_USER="${ADMIN_USER:-kodekloud}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-VMP@55w0rd123}" #az CLI requires 12+ characters
VM_SIZE="${VM_SIZE:-Standard_B1s}"
GW_SKU="${GW_SKU:-VpnGw1AZ}"                   #non-AZ SKUs (VpnGw1) can no longer be created
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\033[1;33;40m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }

#Pre-flight checks
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it with: brew install azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "You are not logged in. Run: az login" >&2; exit 1; }
for f in configureSpoke1.sh configureSpoke2.sh; do
  [ -f "$SCRIPT_DIR/$f" ] || { echo "Missing $SCRIPT_DIR/$f (it must sit next to this script)" >&2; exit 1; }
done

RG="${1:-}"
if [ -z "$RG" ]; then read -rp "(new) Resource Group Name: " RG; fi

#Create RG
info "Creating resource group $RG in $REGION"
az group create -n "$RG" -l "$REGION" -o none

#---------------------------Hub resources (gateway starts first)-----------------------#

info "Creating hub-vnet with default and GatewaySubnet"
az network vnet create -g "$RG" -l "$REGION" -n hub-vnet \
  --address-prefixes 10.2.0.0/16 \
  --subnet-name default --subnet-prefixes 10.2.1.0/24 -o none
az network vnet subnet create -g "$RG" --vnet-name hub-vnet -n GatewaySubnet \
  --address-prefixes 10.2.0.0/28 -o none

info "Creating gateway public IP (Standard, Static)"
az network public-ip create -g "$RG" -l "$REGION" -n pip-vpn-hub \
  --sku Standard --allocation-method Static -o none

info "Starting VPN gateway hub-vpngw ($GW_SKU) - runs in the background"
az network vnet-gateway create -g "$RG" -l "$REGION" -n hub-vpngw \
  --vnet hub-vnet --public-ip-addresses pip-vpn-hub \
  --gateway-type Vpn --vpn-type RouteBased --sku "$GW_SKU" --no-wait -o none

#--------------------------Spoke 1-----------------------#

info "Creating spoke-1-vnet ($REGION)"
az network vnet create -g "$RG" -l "$REGION" -n spoke-1-vnet \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name default --subnet-prefixes 10.0.0.0/24 -o none

info "Creating spoke-1-vm (Apache installed on first boot by configureSpoke1.sh)"
az vm create -g "$RG" -l "$REGION" -n spoke-1-vm \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name spoke-1-vnet --subnet default \
  --public-ip-sku Standard \
  --custom-data "$SCRIPT_DIR/configureSpoke1.sh" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

#--------------------------Spoke 2-----------------------#

info "Creating spoke-2-vnet ($SECONDARY_REGION)"
az network vnet create -g "$RG" -l "$SECONDARY_REGION" -n spoke-2-vnet \
  --address-prefixes 10.1.0.0/16 \
  --subnet-name default --subnet-prefixes 10.1.0.0/24 -o none

info "Creating spoke-2-vm (Apache installed on first boot by configureSpoke2.sh)"
az vm create -g "$RG" -l "$SECONDARY_REGION" -n spoke-2-vm \
  --size "$VM_SIZE" --image Ubuntu2204 \
  --vnet-name spoke-2-vnet --subnet default \
  --public-ip-sku Standard \
  --custom-data "$SCRIPT_DIR/configureSpoke2.sh" \
  --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" --authentication-type password \
  --only-show-errors -o none

info "Waiting for hub-vpngw to finish (this can take 30-45 minutes)..."
az network vnet-gateway wait -g "$RG" -n hub-vpngw --created

#Output
ok "Deployment completed!"
for vm in spoke-1-vm spoke-2-vm; do
  echo "$vm public IP : $(az vm show -d -g "$RG" -n "$vm" --query publicIps -o tsv)  private IP : $(az vm show -d -g "$RG" -n "$vm" --query privateIps -o tsv)"
done
echo "Login with username: $ADMIN_USER  password: $ADMIN_PASSWORD"
