# 060 – Administer Intersite Connectivity

Two independent prep scripts: one for **VNet peering** and one for **service endpoints**. Run whichever one the lab you're doing needs.

| File | Purpose |
|---|---|
| `peering-pref-infra.sh` | Peering prep, Azure CLI version. **Run from zsh on your Mac.** |
| `peering-pref-infra.ps1` | Peering prep, Azure PowerShell version. |
| `service-endpoints-prep-infra.sh` | Service-endpoints prep, Azure CLI version. **Run from zsh on your Mac.** |
| `service-endpoints-prep-infra.ps1` | Service-endpoints prep, Azure PowerShell version. |

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first (`brew install azure-cli`, `az login`), and run this once in the folder:
```zsh
cd "/path/to/AZ-104/v2/060-Administer Intersite Connectivity"
chmod +x *.sh
```

---

## 1. `peering-pref-infra` – VNet peering

Two VNets in different regions with non-overlapping address spaces, each with one VM, ready to be peered.

### What gets created

| Resource | Name | Region | Details |
|---|---|---|---|
| Resource group | `rg-vnet-peering-<yyyyMMdd>` | `eastus` | |
| VM | `vm-eus` | `eastus` | Ubuntu 22.04, `Standard_B1s`, public IP `eus-vm-pip`, SSH (22) open |
| Virtual network | `vnet-eus` | `eastus` | `192.168.0.0/24`, subnet `default` `192.168.0.0/24` |
| VM | `vm-wus` | `westus` | Ubuntu 22.04, `Standard_B1s`, public IP `wus-vm-pip`, SSH (22) open |
| Virtual network | `vnet-wus` | `westus` | `192.168.1.0/24`, subnet `default` `192.168.1.0/24` |

Total: **2 vCPUs**. Deploy time: about 5 minutes.

### Run it

```zsh
./peering-pref-infra.sh
# options
RG=rg-peering REGION=uksouth SECONDARY_REGION=ukwest ./peering-pref-infra.sh
```

### Expected output
```
Deployment completed!
vm-eus public IP : 20.x.x.x  private IP : 192.168.0.4
vm-wus public IP : 13.x.x.x  private IP : 192.168.1.4
Login with username: kodekloud  password: VMP@55w0rd123
```

### Test peering (after you create it in the lab)

```zsh
ssh kodekloud@<vm-eus public IP>
ping 192.168.1.4
```

### Clean up
```zsh
az group delete -n rg-vnet-peering-<yyyyMMdd> --yes --no-wait
```

---

## 2. `service-endpoints-prep-infra` – Service endpoints

A VM in a VNet plus a storage account. In the lab you add a `Microsoft.Storage` service endpoint to the subnet and lock the storage account down to it.

### What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | `rg-se-workload-<yyyyMMdd>` | `eastus` |
| Virtual network | `vnet-01` | `192.168.0.0/16`, subnet `default` `192.168.1.0/24` |
| VM | `vm-01` | Ubuntu 22.04, `Standard_B1s`, public IP `vm-01-pip` (Standard), SSH open |
| Storage account | `st<random><yyyyMMdd>` | StorageV2, Standard_LRS, blob public access allowed |

Total: **1 vCPU**. Deploy time: about 3 minutes.

### Run it

```zsh
./service-endpoints-prep-infra.sh
# options
RG=rg-se-lab REGION=westeurope ./service-endpoints-prep-infra.sh
```

### Expected output
```
Creating resource group rg-se-workload-20261021
Creating VM
vm-01 public IP : 20.x.x.x
Creating storage account st1234520261021
Deployment completed! Storage account: st1234520261021
```

### ⚠️ If `az storage` crashes

If you see `Unable to get API version for type 'ResourceType.DATA_STORAGE_TABLE'`, an outdated `storage-preview` Azure CLI extension is installed. The script checks for this before it starts. Fix it with:
```zsh
az extension remove --name storage-preview
```

### Clean up
```zsh
az group delete -n rg-se-workload-<yyyyMMdd> --yes --no-wait
```

---

## Run the PowerShell versions instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v2/060-Administer Intersite Connectivity"
./peering-pref-infra.ps1
./service-endpoints-prep-infra.ps1
```
The PowerShell versions use password `VMP@55w0rd`.

## Fixes applied

- `service-endpoints-prep-infra.ps1` **never created its resource group**, so `New-AzVM` failed immediately. It now creates `rg-se-workload-<date>` first.
- `service-endpoints-prep-infra.ps1` printed `workload-a-vm- FQDN` (an undefined `$i`). It now prints `vm-01 FQDN`.
- New Azure CLI (`.sh`) versions of both scripts.
