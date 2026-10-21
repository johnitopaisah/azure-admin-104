# Application Gateway lab (v1)

Builds three pools of colour-coded Apache web servers (green, red, blue) plus a jumpbox. During the lab you create an **Application Gateway** with path-based routing:

- `/` → green pool
- `/red/*` → red pool (serves `/red/red.html`)
- `/blue/*` → blue pool (serves `/blue/blue.html`)

## What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | *(you choose)* | `eastus` |
| Virtual network | `color-web-vnet` | `10.0.0.0/16` |
| Subnets | `jumpboxSubnet` / `greenSubnet` / `redSubnet` / `blueSubnet` | `10.0.0.0/24` / `10.0.1.0/24` / `10.0.2.0/24` / `10.0.3.0/24` |
| NSG | `appGwNSG` | Rule `web-rule`: allow TCP 80 from Internet; attached to the green/red/blue subnets |
| VMs | `green-01`, `green-02` | Ubuntu 22.04, `Standard_B1s`, no public IP, page "Hi from green-N" at `/` |
| VMs | `red-01`, `red-02` | Same, page also at `/red/red.html` |
| VMs | `blue-01`, `blue-02` | Same, page also at `/blue/blue.html` |
| VM | `jumpbox-vm` | Ubuntu 22.04, `Standard_B1s`, public IP `jumpbox-appgw-pip` + DNS name |

Total: **7 vCPUs**. Deploy time: about 15 minutes.

> ⚠️ 7 vCPUs is more than some student subscriptions allow per region. Check first:
> `az vm list-usage -l eastus -o table | grep -i "Total Regional vCPUs"`

Leave space in the VNet for the Application Gateway subnet you'll add in the lab, for example `10.0.4.0/24`.

## Files

| File | Purpose |
|---|---|
| `lab-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `lab-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |
| `jumpbox.sh` | Used only by the `.ps1` version. Azure downloads it from GitHub and runs it **on the jumpbox VM**, which SSHes into every pool VM to install Apache. Don't run it on your Mac. |
| `sample.html` | Page template (`PAGECOLOR`, `VMID` placeholders) used by `jumpbox.sh`. |
| `sources.list` | Reference copy of an Ubuntu apt sources file. Not used by any script. |

The `.sh` version doesn't use `jumpbox.sh`: each pool VM installs Apache and writes its own page on first boot.

## Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first.

```zsh
cd "/path/to/AZ-104/v1/AppGateway"
chmod +x lab-infra.sh          # first time only
./lab-infra.sh rg-appgw-lab
```

### Expected output
```
Deployment completed! (Apache finishes installing on the pool VMs a few minutes after boot)
Jumpbox VM DNS name : jumpbox-appgw-1a2b3c4d.eastus.cloudapp.azure.com
Private IP (green-01) : 10.0.1.4
Private IP (green-02) : 10.0.1.5
Private IP (red-01) : 10.0.2.4
...
```

## Check that it worked

Wait 2–3 minutes after the script finishes, then:
```zsh
ssh kodekloud@<jumpbox DNS name>
curl -s 10.0.1.4                 # green
curl -s 10.0.2.4/red/red.html    # red
curl -s 10.0.3.4/blue/blue.html  # blue
```

## Clean up

```zsh
az group delete -n rg-appgw-lab --yes --no-wait
```

Application Gateways bill by the hour, so delete the group when you finish.

## Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v1/AppGateway"
./lab-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd` (which `jumpbox.sh` also expects).

## Fixes applied

- `lab-infra.ps1`: the NSG was created with an undefined variable `$rdpRule`, so it had **no HTTP rule**. It now uses `$webRule`.
- The `kodekloud-azure` GitHub URLs (404) in `lab-infra.ps1` and `jumpbox.sh` → the working `kodekloud-az500` URLs.
- New `lab-infra.sh` Azure CLI version.
