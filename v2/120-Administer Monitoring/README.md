# 120 – Administer Monitoring

Prep script for the **Azure Monitor / Log Analytics / alerts** labs. It gives you a Windows VM, a Linux VM and a web app to collect metrics and logs from.

## Script: `monitoring-prep-infra`

### What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | `rg-secops-<yyyyMMdd>` | `eastus` |
| Virtual network | `vnet-workloads` | `10.0.0.0/16`; subnets `windows` `10.0.1.0/24`, `linux` `10.0.2.0/24` |
| VM | `win-ra-vm` | Windows Server 2022 Datacenter Azure Edition, `Standard_D2s_v3`, public IP, NSG `windows-nsg` (RDP open) |
| VM | `linux-ra-vm` | Ubuntu 22.04, `Standard_B1s`, public IP, NSG `linux-nsg` (SSH open) |
| App Service plan | `asp-<random>` | Windows, Basic **B1** |
| Web app | `demoapp<random>` | Runs on the plan above; URL printed at the end |

Total: **3 vCPUs** + one B1 App Service plan. Deploy time: about 8 minutes.

### Files

| File | Purpose |
|---|---|
| `monitoring-prep-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `monitoring-prep-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |

### Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first (`brew install azure-cli`, `az login`).

```zsh
cd "/path/to/AZ-104/v2/120-Administer Monitoring"
chmod +x monitoring-prep-infra.sh   # first time only
./monitoring-prep-infra.sh
```

Options:
```zsh
RG=rg-mon-lab REGION=westeurope ./monitoring-prep-infra.sh
```

### Expected output
```
Creating App Service
Deployment completed!
win-ra-vm public IP : 20.x.x.x
linux-ra-vm public IP : 20.x.x.x
Web app URL : https://demoapp1234512345.azurewebsites.net
Login with username: kodekloud  password: VMP@55w0rd123
```

### Check that it worked
```zsh
az resource list -g rg-secops-$(date +%Y%m%d) -o table
```

### Clean up
```zsh
az group delete -n rg-secops-<yyyyMMdd> --yes --no-wait
```

The B1 App Service plan bills hourly even when the app is idle, so delete the group when you finish.

### Troubleshooting

- **App Service quota error** (`... quota ... 0 instances` for Basic): some student subscriptions have no Basic App Service quota in a region. Rerun with another `REGION`.

### Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v2/120-Administer Monitoring"
./monitoring-prep-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd`.
