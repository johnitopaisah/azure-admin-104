# AZ-104 v2 lab prep scripts

Each folder matches a module of the AZ-104 course and builds the starting infrastructure for its labs. Every script comes in two equivalent versions:

| Script | Runs in | Tool it uses |
|---|---|---|
| `*-infra.sh` | **zsh / bash on macOS or Linux** | Azure CLI (`az`) |
| `*-infra.ps1` | PowerShell 7 (`pwsh`) on any OS | Azure PowerShell module (`Az`) |

Use **one** of them per lab, not both. The `.sh` versions are recommended on a Mac.

## Labs

| Folder | Script | What it builds | VMs (vCPUs) | Resource group |
|---|---|---|---|---|
| [050- Administer Virtual Networking](050-%20Administer%20Virtual%20Networking/README.md) | `nsg-prep-infra` | 1 VNet, 2 subnets, 4 Linux VMs | 4 (4) | `rg-nsg-workload-<date>` |
| [060-Administer Intersite Connectivity](060-Administer%20Intersite%20Connectivity/README.md) | `peering-pref-infra` | 2 VNets in 2 regions, 1 VM each | 2 (2) | `rg-vnet-peering-<date>` |
| | `service-endpoints-prep-infra` | 1 VM + 1 storage account | 1 (1) | `rg-se-workload-<date>` |
| [070-Administer Network Traffic](070-Administer%20Network%20Traffic/README.md) | `appgw-prep-infra` | VNet, NSG, 6 web servers + jumpbox | 7 (7) | `rg-appgw-<date>` |
| | `loadbalancer-prep-infra` | VNet, NSG, availability set, 3 web servers + jumpbox | 4 (4) | `rg-azlb-<date>` |
| [090-Administer Azure Virtual Machines](090-Administer%20Azure%20Virtual%20Machines/README.md) | `bastion-prep-infra` | 1 VNet, 1 Windows + 1 Linux VM | 2 (3) | `rg-remoteaccess-<date>` |
| [120-Administer Monitoring](120-Administer%20Monitoring/README.md) | `monitoring-prep-infra` | 1 Windows + 1 Linux VM, App Service plan + web app | 2 (3) | `rg-secops-<date>` |

`<date>` is today's date as `yyyyMMdd`, e.g. `rg-appgw-20261021`.

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
   az vm list-usage -l eastus -o table | grep -iE "Total Regional vCPUs|Standard BS Family|DSv3"
   ```

## Running a script from zsh

The folder names contain spaces, so always wrap paths in quotes:

```zsh
cd "/path/to/AZ-104/v2/070-Administer Network Traffic"
./appgw-prep-infra.sh
```

v2 scripts don't ask questions. They name the resource group automatically (see the table above). To choose your own name, set `RG`:

```zsh
RG=rg-my-appgw ./appgw-prep-infra.sh
```

The scripts are bash scripts (`#!/usr/bin/env bash`). Running them from zsh is fine because zsh starts bash for them. If you see `permission denied`, run `chmod +x <script>.sh` once or start it with `bash <script>.sh`.

> If you run the same script twice on the same day, it reuses the same resource group and Azure updates the existing resources in place. To start fresh, delete the group first or pass a new `RG=` name.

### Customising a run

| Variable | Default | Used by |
|---|---|---|
| `RG` | `rg-<lab>-<date>` | all |
| `REGION` | `eastus` | all |
| `SECONDARY_REGION` | `westus` | peering-pref-infra |
| `ADMIN_USER` | `kodekloud` | all |
| `ADMIN_PASSWORD` | `VMP@55w0rd123` | all |
| `VM_SIZE` | `Standard_B1s` | all (Linux VMs) |
| `WIN_VM_SIZE` | `Standard_D2s_v3` | bastion-prep-infra, monitoring-prep-infra |

Example: `REGION=westeurope ADMIN_PASSWORD='MyOwnP@ssw0rd!' ./nsg-prep-infra.sh`

> **Password note:** the course uses `VMP@55w0rd`, but the Azure CLI rejects VM passwords shorter than 12 characters. The `.sh` scripts therefore default to **`VMP@55w0rd123`**. The `.ps1` scripts still use `VMP@55w0rd`.

## Cleaning up (do this after every lab)

```zsh
az group delete -n <resource-group-name> --yes --no-wait
az group list -o table
```

## Alternative: run the PowerShell (`.ps1`) version on a Mac

```zsh
brew install --cask powershell
pwsh -Command 'Install-Module Az -Scope CurrentUser -Repository PSGallery -Force'
pwsh
```
Then inside `pwsh`:
```powershell
Connect-AzAccount
cd "/path/to/AZ-104/v2/070-Administer Network Traffic"
./appgw-prep-infra.ps1
```

## Troubleshooting

| Error | Cause / fix |
|---|---|
| `Azure CLI (az) not found` | `brew install azure-cli` |
| `You are not logged in` | `az login` |
| `RequestDisallowedByPolicy` | Your subscription (common with *Azure for Students*) only allows some regions. Rerun with `REGION=<allowed region>`. |
| `QuotaExceeded` / `OperationNotAllowed ... cores` | Not enough vCPUs. Delete other lab resource groups, use another region, or request a quota increase. |
| `SkuNotAvailable` | That VM size isn't offered in the region. Try `VM_SIZE=Standard_B2s` / `WIN_VM_SIZE=Standard_D2s_v5` or another region. |
| `The password length must be between 12 and 123` | `ADMIN_PASSWORD` needs 12+ characters and 3 of: lower case, upper case, digit, symbol. |
| `'az storage' commands are broken` / `Unable to get API version for type 'ResourceType.DATA_STORAGE_TABLE'` | An outdated `storage-preview` extension. Run `az extension remove --name storage-preview`. |
| `zsh: permission denied` | `chmod +x <script>.sh` or run `bash <script>.sh`. |

## What was fixed compared with the original scripts

- Added Azure CLI (`.sh`) versions of every `.ps1` script.
- `service-endpoints-prep-infra.ps1` never created its resource group, so it failed on the first command. It now creates it, and the output label is fixed (it printed `workload-a-vm-` with an empty variable).
- The `.sh` AppGateway and Load Balancer scripts install Apache on each web server at first boot (cloud-init custom data). They don't depend on a jumpbox SSH-ing into each VM or on files hosted on GitHub.
