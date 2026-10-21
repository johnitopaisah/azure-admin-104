# Azure Load Balancer lab (v1)

Builds three Apache web servers in an availability set, plus a jumpbox. **The load balancer itself isn't included.** You create it during the lab and add the three web servers to its backend pool.

## What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | *(you choose)* | `eastus` |
| Virtual network | `eus-web-dev` | `10.0.0.0/16`; subnets `jumpboxSubnet` `10.0.1.0/24`, `webSubnet` `10.0.2.0/24` |
| NSG | `webNSG` | Rule `web-rule`: allow TCP 80 from Internet; attached to `webSubnet` |
| Availability set | `az-web-set` | 3 fault domains, 3 update domains |
| VMs | `webserver-01`, `-02`, `-03` | Ubuntu 22.04, `Standard_B1s`, **no public IP**, NICs `webserver-0N-nic`. Apache pages: 01 = red, 02 = green, 03 = blue ("Hello from webserver-0N") |
| VM | `jumpbox-vm` | Ubuntu 22.04, `Standard_B1s`, public IP `jumpbox-pip` + DNS name |

Total: **4 vCPUs**. Deploy time: about 10 minutes.

## Files

| File | Purpose |
|---|---|
| `lab-infra.sh` | Azure CLI version. **Run this from zsh on your Mac.** |
| `lab-infra.ps1` | Azure PowerShell version (needs `pwsh` + the `Az` module). |
| `jumpbox.sh` | Used only by the `.ps1` version. Azure downloads it from GitHub and runs it **on the jumpbox VM**, which SSHes into each web server to install Apache. Don't run it on your Mac. |
| `sample.html` | Template page used by `jumpbox.sh` (reference copy). |

The `.sh` version doesn't use `jumpbox.sh`: each web server installs Apache and its coloured page on first boot.

## Run it (macOS / zsh)

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first.

```zsh
cd "/path/to/AZ-104/v1/Azure Load Balancer"
chmod +x lab-infra.sh          # first time only
./lab-infra.sh rg-lb-lab
```

### Expected output
```
Deployment completed! (Apache finishes installing on the web servers a few minutes after boot)
Jumpbox VM DNS name : jumpbox-lb-1a2b3c4d.eastus.cloudapp.azure.com
Private IP (webserver-01) : 10.0.2.4
Private IP (webserver-02) : 10.0.2.5
Private IP (webserver-03) : 10.0.2.6
Login with username: kodekloud  password: VMP@55w0rd123
```

## Check that it worked

Wait 2–3 minutes after the script finishes, then:
```zsh
ssh kodekloud@<jumpbox DNS name>
curl -s 10.0.2.4; curl -s 10.0.2.5; curl -s 10.0.2.6
```
Each server should return its own colour.

## In the lab

Create a load balancer with a backend pool containing the three `webserver-0N-nic` NICs and a TCP/80 health probe and rule. Browse to the load balancer's public IP and refresh to watch the colour change.

## Clean up

```zsh
az group delete -n rg-lb-lab --yes --no-wait
```

## Run the PowerShell version instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v1/Azure Load Balancer"
./lab-infra.ps1
```
The PowerShell version uses password `VMP@55w0rd` (which `jumpbox.sh` also expects).

## Fixes applied

- `lab-infra.ps1`: the NSG was created with an undefined variable `$rdpRule`, so it had **no HTTP rule**. It now uses `$webRule`.
- `UbuntuLTS` → `Ubuntu2204` for the jumpbox.
- The `kodekloud-azure` GitHub URLs (404) in `lab-infra.ps1` and `jumpbox.sh` → the working `kodekloud-az500` URLs.
- New `lab-infra.sh` Azure CLI version.
