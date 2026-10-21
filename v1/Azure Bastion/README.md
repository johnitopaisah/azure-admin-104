# Azure Bastion lab (v1)

Builds a production-style VNet with a Linux and a Windows VM. You then connect to them through **Azure Bastion** during the lab.

## What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | *(you choose)* | `eastus` |
| Virtual network | `prod-eus-vnet` | `10.0.0.0/16` |
| Subnet | `privateSubnet` | `10.0.0.0/24` |
| Linux VM | `linux-prod-server` | Ubuntu 22.04, `Standard_B1s`, public IP + DNS name, NSG allowing SSH (22) |
| Windows VM | `win-prod-server` | Windows Server 2022 Datacenter, `Standard_D2s_v3`, public IP + DNS name, NSG allowing RDP (3389) |

Total: **3 vCPUs**. Deploy time: about 5 minutes.

## Files

| File | Purpose |
|---|---|
| `lab-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `lab-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |

## Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first (`brew install azure-cli`, `az login`).

```zsh
cd "/path/to/AZ-104/v1/Azure Bastion"
chmod +x lab-infra.sh          # first time only
./lab-infra.sh                 # asks: (new) Resource Group Name:
# or
./lab-infra.sh rg-bastion-lab
```

Optional overrides:
```zsh
REGION=westeurope WIN_VM_SIZE=Standard_D2s_v5 ./lab-infra.sh rg-bastion-lab
```

### Expected output
```
Creating resource group rg-bastion-lab in eastus
Creating prod-eus-vnet with privateSubnet
Creating Linux VM
Creating Windows VM
Deployment completed!
Linux VM DNS name   : linux-prod-server-1a2b3c4d.eastus.cloudapp.azure.com
Windows VM DNS name : win-prod-server-1a2b3c4d.eastus.cloudapp.azure.com
Login with username: kodekloud  password: VMP@55w0rd123
```

## Check that it worked

```zsh
az vm list -g rg-bastion-lab -d -o table
az network vnet subnet list -g rg-bastion-lab --vnet-name prod-eus-vnet -o table
```

## In the lab

Azure Bastion needs its own subnet named exactly **`AzureBastionSubnet`**, sized `/26` or larger. `10.0.1.0/26` is free inside `prod-eus-vnet`.

## Clean up

```zsh
az group delete -n rg-bastion-lab --yes --no-wait
```

Bastion bills by the hour, so delete the group when you finish.

## Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v1/Azure Bastion"
./lab-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd` and the default Windows image (Windows Server 2016).

## Fixes applied

- `lab-infra.ps1`: `-Image UbuntuLTS` (Ubuntu 18.04, no longer available) → `Ubuntu2204`.
- New `lab-infra.sh` Azure CLI version (uses Windows Server 2022).
