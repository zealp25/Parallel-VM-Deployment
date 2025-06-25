# Azure VM Provisioning with PowerShell & ARM Template

This project automates the deployment of a **Windows Virtual Machine** on Microsoft Azure using:

- An **ARM template** (`temp.json`) to define infrastructure resources.
- A **PowerShell script** (`vm.ps1`) to deploy everything with one command.

---

## Files Included

| File       | Description |
|------------|-------------|
| `temp.json` | Azure Resource Manager (ARM) template defining the VM, NIC, NSG, public IP, etc. |
| `vm.ps1`    | PowerShell script to deploy the ARM template with your custom parameters. |

---

## Prerequisites

- Azure subscription with necessary permissions
- [Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps) installed and logged in via `Connect-AzAccount`
- Resource group and virtual network already created

---

## Parameters (used in script)

- `imageId`: ID of the custom or marketplace image
- `adminUsername`: Admin account username for the VM
- `adminPassword`: Secure password (entered or stored as secret)
- `computerName`: Hostname for the VM
- `networkInterfaceName`: NIC to associate with the VM
- `subnetId`: Subnet ID where the NIC will reside
- `networkSecurityGroupName`: Name of NSG to link with NIC
- `publicIpAddressName`: Name of public IP for internet access

---

## How to Use

1. **Configure your parameters**  
   Open `vm.ps1` and replace placeholder values with your own.

2. **Run the script**

   ```powershell
   .\vm.ps1
   ```

3. **Wait for deployment**  
   The script will deploy:
   - A Windows VM (`Standard_DS1_v2`)
   - Public IP with dynamic allocation
   - NSG (no default rules — you must add your own)
   - NIC associated with subnet + NSG

---

## Notes

- VM agent and automatic Windows Updates are enabled.
- `licenseType` is set to `Windows_Server` — adjust if using BYOL.
- Make sure to allow RDP (port 3389) via NSG if you want to connect.

---

## License

MIT License. Use it, modify it, deploy it – go nuts (responsibly).
