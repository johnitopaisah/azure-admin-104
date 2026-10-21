# 090 – Administer Azure Virtual Machines

Prep script for the **remote access / Azure Bastion** labs. It builds a Windows VM and a Linux VM in separate subnets, each with its own NSG, so you can practise RDP, SSH, Bastion and just-in-time access.

## Script: `bastion-prep-infra`

### What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | `rg-remoteaccess-<yyyyMMdd>` | `eastus` |
| Virtual network | `vnet-remoteaccess` | `10.0.0.0/16` |
| Subnet | `windows` | `10.0.1.0/24` |
| Subnet | `linux` | `10.0.2.0/24` |
| VM | `win-ra-vm` | Windows Server 2022 Datacenter Azure Edition, `Standard_D2s_v3`, public IP, NSG `windows-nsg` (RDP 3389 open) |
| VM | `linux-ra-vm` | Ubuntu 22.04, `Standard_B1s`, public IP, NSG `linux-nsg` (SSH 22 open) |

Total: **3 vCPUs**. Deploy time: about 6 minutes.

### Files

| File | Purpose |
|---|---|
| `bastion-prep-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `bastion-prep-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |

### Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first (`brew install azure-cli`, `az login`).

```zsh
cd "/path/to/AZ-104/v2/090-Administer Azure Virtual Machines"
chmod +x bastion-prep-infra.sh   # first time only
./bastion-prep-infra.sh
```

Options:
```zsh
RG=rg-ra-lab REGION=westeurope WIN_VM_SIZE=Standard_D2s_v5 ./bastion-prep-infra.sh
```

### Expected output
```
Creating resource group rg-remoteaccess-20261021
Creating vnet-remoteaccess with windows and linux subnets
Creating Windows VM
Creating Linux VM
Deployment completed!
win-ra-vm public IP : 20.x.x.x
linux-ra-vm public IP : 20.x.x.x
Login with username: kodekloud  password: VMP@55w0rd123
```

### Connect from your Mac

```zsh
ssh kodekloud@<linux-ra-vm public IP>
```
For Windows, install **Windows App** (formerly Microsoft Remote Desktop) from the Mac App Store and add a PC with `<win-ra-vm public IP>`.

### In the lab

Azure Bastion needs a subnet named exactly **`AzureBastionSubnet`**, sized `/26` or larger. `10.0.3.0/26` is free in `vnet-remoteaccess`.

### Clean up
```zsh
az group delete -n rg-remoteaccess-<yyyyMMdd> --yes --no-wait
```

### Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v2/090-Administer Azure Virtual Machines"
./bastion-prep-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd` and the default Windows size (`Standard_DS1_v2`).
