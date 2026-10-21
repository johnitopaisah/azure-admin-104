# 050 – Administer Virtual Networking

Prep script for the **Network Security Group (NSG)** labs. It builds a VNet with two workload subnets and two Linux VMs in each, so you can practise NSG rules, ASGs and effective security rules between subnets.

## Script: `nsg-prep-infra`

### What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | `rg-nsg-workload-<yyyyMMdd>` | `eastus` |
| Virtual network | `vnet-workloads` | `192.168.0.0/16` |
| Subnet | `snet-workload-a` | `192.168.1.0/24` |
| Subnet | `snet-workload-b` | `192.168.2.0/24` |
| VMs | `workload-a-vm-1`, `workload-a-vm-2` | Ubuntu 22.04, `Standard_B1s`, in `snet-workload-a` |
| VMs | `workload-b-vm-1`, `workload-b-vm-2` | Ubuntu 22.04, `Standard_B1s`, in `snet-workload-b` |
| Public IPs | `workload-<a\|b>-vm-<n>-pip` | Standard SKU, with a DNS name |
| NSGs | `workload-<a\|b>-vm-<n>NSG` | One per VM NIC, created automatically, allows SSH (22) |

Total: **4 vCPUs**. Deploy time: about 8 minutes.

### Files

| File | Purpose |
|---|---|
| `nsg-prep-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `nsg-prep-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |

### Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first (`brew install azure-cli`, `az login`).

```zsh
cd "/path/to/AZ-104/v2/050- Administer Virtual Networking"
chmod +x nsg-prep-infra.sh     # first time only
./nsg-prep-infra.sh
```

Options:
```zsh
RG=rg-nsg-lab REGION=westeurope ./nsg-prep-infra.sh
```

### Expected output
```
Adding resource group : rg-nsg-workload-20261021
Adding workload network configuration
Creating workload-a-vm-1
workload-a-vm-1 FQDN : workload-a-vm-1-1a2b3c4d.eastus.cloudapp.azure.com
Creating workload-b-vm-1
workload-b-vm-1 FQDN : workload-b-vm-1-1a2b3c4d.eastus.cloudapp.azure.com
...
Deployment completed! Login with username: kodekloud  password: VMP@55w0rd123
```

### Check that it worked

```zsh
az vm list -g rg-nsg-workload-$(date +%Y%m%d) -d -o table
az network nsg list -g rg-nsg-workload-$(date +%Y%m%d) -o table
```

### Clean up

```zsh
az group delete -n rg-nsg-workload-<yyyyMMdd> --yes --no-wait
```

### Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v2/050- Administer Virtual Networking"
./nsg-prep-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd`.

> Note: the folder name has a space after `050-`. Keep the quotes around the path.
