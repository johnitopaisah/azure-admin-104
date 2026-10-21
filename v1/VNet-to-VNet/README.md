# VNet-to-VNet VPN lab (v1)

Builds two VNets in two regions, each with a VM and a **route-based VPN gateway**. You then create the VNet-to-VNet connections between the gateways during the lab.

> ⏱ **This lab takes 30–45 minutes to deploy** because of the VPN gateways. The script builds both gateways at the same time and waits for them. Keep the terminal open.
>
> 💰 VPN gateways bill every hour they exist. Delete the resource group as soon as you finish.

## What gets created

| Resource | Name | Region | Details |
|---|---|---|---|
| Resource group | *(you choose)* | `eastus` | |
| Virtual network | `eus-vnet` | `eastus` | `10.0.0.0/16`; subnets `default` `10.0.1.0/24`, `GatewaySubnet` `10.0.0.0/28` |
| Virtual network | `wus-vnet` | `westus` | `192.168.0.0/16`; subnets `default` `192.168.1.0/24`, `GatewaySubnet` `192.168.0.0/28` |
| VM | `eus-prod-server` | `eastus` | Ubuntu 22.04, `Standard_B1s`, public IP `eus-vm-pip` |
| VM | `wus-prod-server` | `westus` | Ubuntu 22.04, `Standard_B1s`, public IP |
| Public IP | `pip-vpn-eus`, `pip-vpn-wus` | each | Standard SKU, Static |
| VPN gateway | `vpngw-eus`, `vpngw-wus` | each | Route-based, SKU `VpnGw1AZ` |

## Files

| File | Purpose |
|---|---|
| `lab-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `lab-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |

## Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first.

```zsh
cd "/path/to/AZ-104/v1/VNet-to-VNet"
chmod +x lab-infra.sh          # first time only
./lab-infra.sh rg-v2v-lab
```

Options:
```zsh
REGION=uksouth SECONDARY_REGION=ukwest ./lab-infra.sh rg-v2v-lab   # other regions
GW_SKU=VpnGw2AZ ./lab-infra.sh rg-v2v-lab                          # bigger gateway
```

If the terminal closes while it's waiting, the gateways keep building in Azure. Check on them with:
```zsh
az network vnet-gateway list -g rg-v2v-lab --query "[].{name:name, state:provisioningState}" -o table
```

### Expected output (end)
```
Waiting for both VPN gateways to finish (this can take 30-45 minutes)...
Deployment completed!
East US VM DNS name : eus-prod-server-1a2b3c4d.eastus.cloudapp.azure.com
West US VM DNS name : wus-prod-server-1a2b3c4d.westus.cloudapp.azure.com
```

## In the lab: connecting the gateways

The lab has you create the two connections. With the Azure CLI, that looks like this (use the same shared key on both):
```zsh
az network vpn-connection create -g rg-v2v-lab -n eus-to-wus --vnet-gateway1 vpngw-eus \
  --vnet-gateway2 vpngw-wus --shared-key 'Az104SharedKey' -l eastus
az network vpn-connection create -g rg-v2v-lab -n wus-to-eus --vnet-gateway1 vpngw-wus \
  --vnet-gateway2 vpngw-eus --shared-key 'Az104SharedKey' -l westus
```

## Clean up

```zsh
az group delete -n rg-v2v-lab --yes --no-wait
```

## Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v1/VNet-to-VNet"
./lab-infra.ps1
```
The PowerShell version creates the gateways one after another, so it takes longer: up to about 90 minutes.

## Fixes applied

- `UbuntuLTS` → `Ubuntu2204`.
- Gateway public IPs were Basic/Dynamic, which Azure no longer lets you create. They're now **Standard/Static**.
- Gateway SKU `VpnGw1` (non-AZ, retired in 2026) → **`VpnGw1AZ`**.
- New `lab-infra.sh` Azure CLI version (builds both gateways in parallel).
