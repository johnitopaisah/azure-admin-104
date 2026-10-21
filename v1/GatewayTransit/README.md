# Gateway Transit lab (v1)

Builds a **hub-and-spoke** topology: a hub VNet with a VPN gateway, plus two spoke VNets, each with a small Apache web server. During the lab you peer the spokes to the hub and enable **gateway transit** / **use remote gateways**.

> ⏱ **This lab takes 30–45 minutes to deploy** because of the hub VPN gateway. The script starts the gateway first, builds the spokes while it provisions, then waits for it.
>
> 💰 VPN gateways bill every hour they exist. Delete the resource group as soon as you finish.

## What gets created

| Resource | Name | Region | Details |
|---|---|---|---|
| Resource group | *(you choose)* | `eastus` | |
| Virtual network | `hub-vnet` | `eastus` | `10.2.0.0/16`; subnets `default` `10.2.1.0/24`, `GatewaySubnet` `10.2.0.0/28` |
| Public IP | `pip-vpn-hub` | `eastus` | Standard SKU, Static |
| VPN gateway | `hub-vpngw` | `eastus` | Route-based, SKU `VpnGw1AZ` |
| Virtual network | `spoke-1-vnet` | `eastus` | `10.0.0.0/16`, subnet `default` `10.0.0.0/24` |
| VM | `spoke-1-vm` | `eastus` | Ubuntu 22.04, `Standard_B1s`, public IP, Apache with a **red** "Hi from Spoke-1" page |
| Virtual network | `spoke-2-vnet` | `westus` | `10.1.0.0/16`, subnet `default` `10.1.0.0/24` |
| VM | `spoke-2-vm` | `westus` | Ubuntu 22.04, `Standard_B1s`, public IP, Apache with a **blue** "Hi from Spoke-2" page |

## Files

| File | Purpose |
|---|---|
| `lab-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `lab-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |
| `configureSpoke1.sh` | Runs **on spoke-1-vm** (not on your Mac): installs Apache and writes the red page. |
| `configureSpoke2.sh` | Runs **on spoke-2-vm** (not on your Mac): installs Apache and writes the blue page. |

Both lab scripts upload `configureSpoke*.sh` from this folder automatically. Keep them next to `lab-infra.sh` / `lab-infra.ps1`, and don't run them on your Mac.

## Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first.

```zsh
cd "/path/to/AZ-104/v1/GatewayTransit"
chmod +x lab-infra.sh          # first time only
./lab-infra.sh rg-hubspoke-lab
```

Options:
```zsh
REGION=uksouth SECONDARY_REGION=ukwest ./lab-infra.sh rg-hubspoke-lab
```

Check the gateway's progress from another terminal:
```zsh
az network vnet-gateway show -g rg-hubspoke-lab -n hub-vpngw --query provisioningState -o tsv
```

### Expected output (end)
```
Deployment completed!
spoke-1-vm public IP : 20.x.x.x  private IP : 10.0.0.4
spoke-2-vm public IP : 13.x.x.x  private IP : 10.1.0.4
Login with username: kodekloud  password: VMP@55w0rd123
```

## Check that it worked

```zsh
az vm list -g rg-hubspoke-lab -d -o table
# Apache takes 2-3 minutes after the VM boots; then, from a spoke VM:
ssh kodekloud@<spoke-1 public IP> "curl -s localhost"
```

## Clean up

```zsh
az group delete -n rg-hubspoke-lab --yes --no-wait
```

## Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v1/GatewayTransit"
./lab-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd`.

## Fixes applied

- `UbuntuLTS` → `Ubuntu2204`.
- The `.ps1` built the Custom Script extension parameters but **never called `Set-AzVMExtension`**, so Apache was never installed. It also pointed at GitHub URLs that now return 404. It now sends the local `configureSpoke*.sh` to each VM.
- Removed dangling line-continuation backticks after `-Credential $credential`.
- Hub gateway public IP Basic/Dynamic → Standard/Static. Gateway SKU `VpnGw1` → `VpnGw1AZ`.
- `configureSpoke*.sh`: `chown -R 777` (wrong command) → `chmod -R 777`. `apt` now waits for the package lock at first boot.
- New `lab-infra.sh` Azure CLI version.
