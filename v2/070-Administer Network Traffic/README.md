# 070 – Administer Network Traffic

Two independent prep scripts: one for the **Application Gateway** lab and one for the **Azure Load Balancer** lab. Neither creates the gateway or load balancer itself. You build that during the lab.

| File | Purpose |
|---|---|
| `appgw-prep-infra.sh` | App Gateway prep, Azure CLI version. **Run from zsh on your Mac.** |
| `appgw-prep-infra.ps1` | App Gateway prep, Azure PowerShell version. |
| `loadbalancer-prep-infra.sh` | Load Balancer prep, Azure CLI version. **Run from zsh on your Mac.** |
| `loadbalancer-prep-infra.ps1` | Load Balancer prep, Azure PowerShell version. |

Do the one-time setup in [../README.md](../README.md#one-time-setup-macos--zsh) first (`brew install azure-cli`, `az login`), and run this once in the folder:
```zsh
cd "/path/to/AZ-104/v2/070-Administer Network Traffic"
chmod +x *.sh
```

### How the web servers get configured

- **`.sh` versions:** each web server installs Apache and writes its coloured page itself on first boot (cloud-init custom data). Nothing is downloaded from GitHub, and there's no SSH from the jumpbox. Pages are ready 2–3 minutes after the script ends.
- **`.ps1` versions:** a Custom Script extension downloads `jumpbox.sh` from GitHub (`rithinskaria/kodekloud-az500`) and runs it on the jumpbox, which SSHes into each server with password `VMP@55w0rd`.

---

## 1. `appgw-prep-infra` – Application Gateway

Three colour-coded pools for path-based routing: `/` → green, `/red/*` → red, `/blue/*` → blue.

### What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | `rg-appgw-<yyyyMMdd>` | `eastus` |
| Virtual network | `color-web-vnet` | `10.0.0.0/16` |
| Subnets | `jumpboxSubnet` / `greenSubnet` / `redSubnet` / `blueSubnet` | `10.0.0.0/24` / `10.0.1.0/24` / `10.0.2.0/24` / `10.0.3.0/24` |
| NSG | `appGwNSG` | `web-rule`: allow TCP 80 from Internet, on the 3 pool subnets |
| VMs | `green-01/02`, `red-01/02`, `blue-01/02` | Ubuntu 22.04, `Standard_B1s`, no public IP, NICs `<color>-0N-nic`. Red/blue also serve `/red/red.html` / `/blue/blue.html` |
| VM | `jumpbox-vm` | Ubuntu 22.04, `Standard_B1s`, public IP `jumpbox-appgw-pip` + DNS name |

Total: **7 vCPUs**. Deploy time: about 15 minutes.

> ⚠️ 7 vCPUs is more than some student subscriptions allow per region. Check first:
> `az vm list-usage -l eastus -o table | grep -i "Total Regional vCPUs"`

### Run it

```zsh
./appgw-prep-infra.sh
# options
RG=rg-appgw-lab REGION=westeurope ./appgw-prep-infra.sh
```

### Expected output
```
Deployment completed! (Apache finishes installing on the pool VMs a few minutes after boot)
Jumpbox VM DNS name : jumpbox-appgw-1a2b3c4d.eastus.cloudapp.azure.com
Private IP (green-01) : 10.0.1.4
Private IP (green-02) : 10.0.1.5
Private IP (blue-01) : 10.0.3.4
...
Use username: kodekloud and password: VMP@55w0rd123 to login to any VMs
```

### Check that it worked
```zsh
ssh kodekloud@<jumpbox DNS name>
curl -s 10.0.1.4                 # green
curl -s 10.0.2.4/red/red.html    # red
curl -s 10.0.3.4/blue/blue.html  # blue
```

For the Application Gateway you'll need an extra subnet, for example `10.0.4.0/24`, inside `color-web-vnet`.

### Clean up
```zsh
az group delete -n rg-appgw-<yyyyMMdd> --yes --no-wait
```

---

## 2. `loadbalancer-prep-infra` – Azure Load Balancer

Three web servers in an availability set, each serving a different colour, so you can watch the load balancer distribute traffic.

### What gets created

| Resource | Name | Details |
|---|---|---|
| Resource group | `rg-azlb-<yyyyMMdd>` | `eastus` |
| Virtual network | `eus-web-dev` | `10.0.0.0/16`; `jumpboxSubnet` `10.0.1.0/24`, `webSubnet` `10.0.2.0/24` |
| NSG | `webNSG` | `web-rule`: allow TCP 80 from Internet, on `webSubnet` |
| Availability set | `az-web-set` | 3 fault / 3 update domains |
| VMs | `webserver-01` (red), `-02` (green), `-03` (blue) | Ubuntu 22.04, `Standard_B1s`, no public IP, NICs `webserver-0N-nic` |
| VM | `jumpbox-vm` | Ubuntu 22.04, `Standard_B1s`, public IP `jumpbox-pip` + DNS name |

Total: **4 vCPUs**. Deploy time: about 10 minutes.

### Run it

```zsh
./loadbalancer-prep-infra.sh
# options
RG=rg-lb-lab REGION=westeurope ./loadbalancer-prep-infra.sh
```

### Expected output
```
Deployment completed! (Apache finishes installing on the web servers a few minutes after boot)
Jumpbox VM DNS name : jumpbox-lb-1a2b3c4d.eastus.cloudapp.azure.com
Private IP (webserver-01) : 10.0.2.4
Private IP (webserver-02) : 10.0.2.5
Private IP (webserver-03) : 10.0.2.6
```

### Check that it worked
```zsh
ssh kodekloud@<jumpbox DNS name>
curl -s 10.0.2.4; curl -s 10.0.2.5; curl -s 10.0.2.6
```

### Clean up
```zsh
az group delete -n rg-azlb-<yyyyMMdd> --yes --no-wait
```

---

## Run the PowerShell versions instead

```powershell
# inside pwsh, after Connect-AzAccount
cd "/path/to/AZ-104/v2/070-Administer Network Traffic"
./appgw-prep-infra.ps1
./loadbalancer-prep-infra.ps1
```
The PowerShell versions use password `VMP@55w0rd`. Their `jumpbox.sh` scripts depend on that password, so don't change it in the `.ps1`.
