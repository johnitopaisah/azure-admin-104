# AZ-104 v1 lab scripts

Each folder builds the starting infrastructure for one hands-on lab. Every lab has two equivalent scripts:

| Script | Runs in | Tool it uses |
|---|---|---|
| `lab-infra.sh` | **zsh / bash on macOS or Linux** | Azure CLI (`az`) |
| `lab-infra.ps1` | PowerShell 7 (`pwsh`) on any OS | Azure PowerShell module (`Az`) |

Use **one** of them per lab, not both. The `.sh` versions are recommended on a Mac.

## Labs

| Folder | What it builds | VMs (vCPUs) | Approx. deploy time |
|---|---|---|---|
| [Azure Bastion](Azure%20Bastion/README.md) | 1 VNet, 1 Linux + 1 Windows VM | 2 (3) | ~5 min |
| [Peering](Peering/README.md) | 2 VNets in 2 regions, 1 VM in each | 2 (2) | ~5 min |
| [VNet-to-VNet](VNet-to-VNet/README.md) | 2 VNets in 2 regions, 2 VMs, 2 VPN gateways | 2 (2) | **30–45 min** |
| [GatewayTransit](GatewayTransit/README.md) | Hub VNet with VPN gateway + 2 spoke VNets with web VMs | 2 (2) | **30–45 min** |
| [Azure Load Balancer](Azure%20Load%20Balancer/README.md) | VNet, NSG, availability set, 3 web servers + jumpbox | 4 (4) | ~10 min |
| [AppGateway](AppGateway/README.md) | VNet, NSG, 6 colour-coded web servers + jumpbox | 7 (7) | ~15 min |

---

## One-time setup (macOS + zsh)

1. **Install the Azure CLI** (skip if `az version` already works):
   ```zsh
   brew update && brew install azure-cli
   ```
2. **Sign in and choose your subscription:**
   ```zsh
   az login
   az account show -o table                      # check which subscription is active
   az account set --subscription "<name or id>"  # only if you need to switch
   ```
3. **Check your vCPU quota** in the region you'll use (student subscriptions are often limited):
   ```zsh
   az vm list-usage -l eastus -o table | grep -iE "Total Regional vCPUs|Standard BS Family"
   ```
   Make sure `Limit - CurrentValue` is at least the vCPU count in the table above.

## Running a script from zsh

The folder names contain spaces, so always wrap paths in quotes:

```zsh
cd "/path/to/AZ-104/v1/Azure Bastion"
./lab-infra.sh                  # prompts for a new resource group name
./lab-infra.sh rg-bastion-lab   # or pass the name as the first argument
```

The scripts are bash scripts (`#!/usr/bin/env bash`). Running them from zsh is fine because zsh starts bash for them. If you see `permission denied`, either run `chmod +x lab-infra.sh` once or start it with `bash lab-infra.sh`.

### Customising a run

Every `.sh` script reads optional environment variables. Put them in front of the command:

```zsh
REGION=westeurope ./lab-infra.sh rg-test
REGION=uksouth SECONDARY_REGION=ukwest ./lab-infra.sh rg-peering
ADMIN_PASSWORD='MyOwnP@ssw0rd!' ./lab-infra.sh rg-test
```

| Variable | Default | Used by |
|---|---|---|
| `REGION` | `eastus` | all |
| `SECONDARY_REGION` | `westus` | Peering, VNet-to-VNet, GatewayTransit |
| `ADMIN_USER` | `kodekloud` | all |
| `ADMIN_PASSWORD` | `VMP@55w0rd123` | all |
| `VM_SIZE` / `LINUX_VM_SIZE` | `Standard_B1s` | all |
| `WIN_VM_SIZE` | `Standard_D2s_v3` | Azure Bastion |
| `GW_SKU` | `VpnGw1AZ` | VNet-to-VNet, GatewayTransit |

> **Password note:** the course uses `VMP@55w0rd`, but the Azure CLI rejects VM passwords shorter than 12 characters. The `.sh` scripts therefore default to **`VMP@55w0rd123`**. The `.ps1` scripts still use `VMP@55w0rd`.

## Cleaning up (do this after every lab)

Everything a script creates goes into one resource group, so deleting the group removes it all:

```zsh
az group delete -n <resource-group-name> --yes --no-wait
az group list -o table          # confirm it is gone / deleting
```

VPN gateways (VNet-to-VNet, GatewayTransit) bill every hour they exist, so delete those labs as soon as you finish.

## Alternative: run the PowerShell (`.ps1`) version on a Mac

```zsh
brew install --cask powershell
pwsh -Command 'Install-Module Az -Scope CurrentUser -Repository PSGallery -Force'
pwsh
```
Then inside `pwsh`:
```powershell
Connect-AzAccount
cd "/path/to/AZ-104/v1/Azure Bastion"
./lab-infra.ps1
```

## Troubleshooting

| Error | Cause / fix |
|---|---|
| `Azure CLI (az) not found` | `brew install azure-cli` |
| `You are not logged in` | `az login` |
| `RequestDisallowedByPolicy` | Your subscription (common with *Azure for Students*) only allows some regions. Rerun with `REGION=<allowed region>` (and `SECONDARY_REGION=...`). |
| `QuotaExceeded` / `OperationNotAllowed ... cores` | Not enough vCPUs. Delete other lab resource groups, use a different region, or request a quota increase. |
| `SkuNotAvailable` | That VM size isn't offered in the region. Try `VM_SIZE=Standard_B2s` or another region. |
| `The password length must be between 12 and 123` | Your `ADMIN_PASSWORD` is too short. It needs 12+ characters and 3 of: lower case, upper case, digit, symbol. |
| `DnsRecordInUse` / name already exists | Rerun the script; DNS labels get a random suffix each run. |
| `ResourceGroupBeingDeleted` | You reused the name of a group that is still deleting. Wait, or pick a new name. |
| `zsh: permission denied: ./lab-infra.sh` | `chmod +x lab-infra.sh` or run `bash lab-infra.sh`. |

## What was fixed compared with the original scripts

- Added `lab-infra.sh` (Azure CLI) versions of every `.ps1` script.
- `UbuntuLTS` (Ubuntu 18.04, retired) → `Ubuntu2204` in every lab.
- Gateway public IPs: Basic/Dynamic (no longer creatable) → Standard/Static. Gateway SKU `VpnGw1` (non-AZ, retired) → `VpnGw1AZ`.
- AppGateway and Load Balancer: the NSG was created with an undefined `$rdpRule`, so it had **no HTTP rule**. It now uses `$webRule`.
- Peering: the West US VM asked for subnet `default`, which doesn't exist in `wus-vnet`. It now uses `privateSubnet`.
- GatewayTransit: the Custom Script extension was never applied, and its GitHub URLs returned 404. The scripts now run the local `configureSpoke*.sh`. Fixed `chown 777` → `chmod 777` in those scripts.
- AppGateway and Load Balancer `jumpbox.sh` + `.ps1`: dead `kodekloud-azure` GitHub URLs replaced with the working `kodekloud-az500` ones. The `.sh` versions don't need the jumpbox script at all: each web server installs Apache itself on first boot.
