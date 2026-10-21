# VNet Peering lab (v1)

Builds two VNets in two different regions, each with one Linux VM. You then connect them with **global VNet peering** during the lab.

## What gets created

| Resource | Name | Region | Details |
|---|---|---|---|
| Resource group | *(you choose)* | `eastus` | |
| Virtual network | `eus-vnet` | `eastus` | `10.0.0.0/16`, subnet `default` `10.0.0.0/24` |
| Virtual network | `wus-vnet` | `westus` | `192.168.0.0/16`, subnet `privateSubnet` `192.168.1.0/24` |
| VM | `eus-prod-server` | `eastus` | Ubuntu 22.04, `Standard_B1s`, public IP `eus-vm-pip`, SSH open |
| VM | `wus-prod-server` | `westus` | Ubuntu 22.04, `Standard_B1s`, public IP, SSH open |

Total: **2 vCPUs**. Deploy time: about 5 minutes.

## Files

| File | Purpose |
|---|---|
| `lab-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `lab-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |

## Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first.

```zsh
cd "/path/to/AZ-104/v1/Peering"
chmod +x lab-infra.sh          # first time only
./lab-infra.sh rg-peering-lab
```

If your subscription doesn't allow `eastus`/`westus`, use any two allowed regions:
```zsh
REGION=uksouth SECONDARY_REGION=ukwest ./lab-infra.sh rg-peering-lab
```

### Expected output
```
Deployment completed!
East US VM DNS name : eus-prod-server-1a2b3c4d.eastus.cloudapp.azure.com
West US VM DNS name : wus-prod-server-1a2b3c4d.westus.cloudapp.azure.com
Login with username: kodekloud  password: VMP@55w0rd123
```

## Check that it worked

```zsh
az vm list -g rg-peering-lab -d -o table
az network vnet list -g rg-peering-lab -o table
```

To test peering later, SSH to the East US VM and ping the West US VM's private IP (`192.168.1.4`):
```zsh
ssh kodekloud@<east-us-dns-name>
ping 192.168.1.4
```

## Clean up

```zsh
az group delete -n rg-peering-lab --yes --no-wait
```

## Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v1/Peering"
./lab-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd`.

## Fixes applied

- `lab-infra.ps1`: `UbuntuLTS` → `Ubuntu2204`.
- `lab-infra.ps1`: the West US VM asked for subnet `default`, which doesn't exist in `wus-vnet`. It now uses `privateSubnet`.
- New `lab-infra.sh` Azure CLI version.
