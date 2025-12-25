# Azure Hyper-V Migration Lab (Terraform)

This lab provisions an Azure Windows Server VM and configures it as a Hyper-V host. After Hyper-V is installed (requires reboot), the script continues automatically and creates:
- An **Internal** Hyper-V vSwitch: `InternalSwitch`
- Two test VMs: `TestVM01`, `TestVM02`

## Repository layout (key files)

- `providers.tf` – AzureRM provider config
- `variables.tf` – inputs (location, RG name, admin creds)
- `tarraform.tfvars` – example variable values (note file name)
- `network.tf` – RG, VNet, Subnet, NSG + association
- `hyperv.tf` – Public IP, NIC, Windows VM, and VM extension
- `scripts/install-hyperv.ps1` – Hyper-V installation + post-reboot VM creation
- `outputs.tf` – outputs the public IP of the Hyper-V host

## What Terraform deploys (Azure resources)

1. **Resource Group**: `azurerm_resource_group.rg`
2. **Network**:
   - VNet: `azurerm_virtual_network.vnet` (`10.10.0.0/16`)
   - Subnet: `azurerm_subnet.subnet` (`10.10.1.0/24`)
   - NSG: `azurerm_network_security_group.nsg` allowing inbound TCP/3389 (RDP)
   - NSG association to subnet
3. **Connectivity**:
   - Public IP (Static/Standard): `azurerm_public_ip.hyperv_pip`
   - NIC: `azurerm_network_interface.hyperv_nic`
4. **Compute**:
   - Windows VM: `azurerm_windows_virtual_machine.hyperv_host`
5. **Bootstrap**:
   - Custom Script Extension: `azurerm_virtual_machine_extension.hyperv_install`

## How the workflow works (end-to-end)

### 1) Terraform apply
- `main.tf` base64-encodes `scripts/install-hyperv.ps1` into `local.install_script_b64`.
- `azurerm_virtual_machine_extension.hyperv_install` writes that content to:
  - `C:\Temp\install-hyperv.ps1`
- Then it executes:
  - `C:\Temp\install-hyperv.ps1`

### 2) First script run (pre-reboot)
On first run, `install-hyperv.ps1`:
- Checks whether **Hyper-V** is installed: `Get-WindowsFeature -Name Hyper-V`
- If not installed:
  - Ensures `C:\Temp\install-hyperv.ps1` exists (stable path)
  - Registers a **Startup Scheduled Task** (`InstallHyperVPostReboot`) running as **SYSTEM**
    - This is critical because the VM must reboot after installing Hyper-V.
  - Installs Hyper-V + tools and triggers a reboot:
    - `Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart`

### 3) Second script run (post-reboot continuation)
After reboot:
- The scheduled task runs the same script again.
- The script removes the scheduled task (one-time behavior).
- It waits briefly for Hyper-V components/services to be ready, then:
  - Creates `InternalSwitch` (Internal vSwitch) if missing
  - Creates `TestVM01` and `TestVM02` if missing

### 4) Logging
The script writes a transcript to:
- `C:\Temp\install-hyperv.log`

Use this log to confirm whether the post-reboot portion executed.

## How to run

From this folder:

```bash
terraform init
terraform plan -var-file="tarraform.tfvars"
terraform apply -var-file="tarraform.tfvars"
```

After apply:
- Get the public IP from `terraform output hyperv_public_ip`
- RDP to the host on port 3389 using `admin_username` / `admin_password`

## Validation (inside the Hyper-V host)

Open an elevated PowerShell session:

```powershell
Get-WindowsFeature Hyper-V
Get-VMSwitch
Get-VM
```

Expected:
- Hyper-V Installed = `True`
- Switch exists: `InternalSwitch`
- VMs exist: `TestVM01`, `TestVM02`

Also check the transcript:
```powershell
Get-Content C:\Temp\install-hyperv.log -Tail 200
```

## Troubleshooting

### VMs not created
Common causes:
- Post-reboot continuation didn’t run (scheduled task didn’t execute)
- Hyper-V services weren’t ready when VM creation ran

What to check:
- Task existence/history:
  - `Get-ScheduledTask -TaskName InstallHyperVPostReboot -ErrorAction SilentlyContinue`
- Transcript log:
  - `C:\Temp\install-hyperv.log`
- Hyper-V service:
  - `Get-Service vmms`

### Extension succeeded but script didn’t persist
The extension writes the script to `C:\Temp\install-hyperv.ps1`. Confirm it exists:
```powershell
Test-Path C:\Temp\install-hyperv.ps1
```

## Notes / security
- Storing admin passwords in `.tfvars` is not recommended for real environments. Prefer Key Vault, environment variables, or CI secrets.
- The NSG rule allows inbound RDP from `*`. Restrict this to your public IP for safer usage.



# Step-by-Step Guide to Enable Internet Access
### 1. Create a NAT Virtual Switch
On your Azure VM (the Hyper-V Host), you need a specific type of internal switch. Open PowerShell as Administrator and run:

```PowerShell
# Create an Internal Virtual Switch
New-VMSwitch -Name "InternalNAT" -SwitchType Internal
```

### 2. Configure the Gateway IP
Now, assign an IP address to the "Internal" interface you just created. This will act as the Default Gateway for your nested VMs.
```PowerShell
# Assign an IP to the Virtual Switch interface
# We will use 192.168.0.1 as the gateway
New-NetIPAddress -IPAddress 192.168.0.1 -PrefixLength 24 -InterfaceAlias "vEthernet (InternalNAT)"
```
### 3. Create the NAT Network
This is the "magic" step. It tells Windows to translate traffic from the internal range to the Azure VM's external NIC.
```PowerShell
# Define the NAT rule for the subnet
New-NetNat -Name "NestedNAT" -InternalIPInterfaceAddressPrefix 192.168.0.0/24
```
4. Configure the Nested VMs
Now that the host is ready, you must configure the network settings inside your Hyper-V VMs (Guest 1 and Guest 2):

   1.  **Change the Switch**: In Hyper-V Manager, go to the settings of your VMs and ensure their Network Adapter is connected to the "InternalNAT" switch.

   2. Assign Static IPs: Inside the Guest OS, assign IPs within the range you created:

      - IP Address: `192.168.0.10` (and `.11` for the second VM)

      - Subnet Mask: `255.255.255.0`

      - Default Gateway: `192.168.0.1` (The IP we gave the switch)

      - DNS: Use Google DNS `(8.8.8.8)` or Azure DNS `(168.63.129.16)`.

# If copy and paste is not working then use the below

In a professional Azure/Hyper-V environment, copy-pasting text and files between a host and a guest requires **Enhanced Session Mode**. This mode uses the Remote Desktop Protocol (RDP) over the VMBus to allow resource redirection (clipboard, drives, etc.) without needing a network connection.

Since you are in a nested virtualization setup (Azure VM -> Hyper-V Host -> Nested VM), there are three layers where this needs to be enabled.

1. **Enable Enhanced Session on the Hyper-V Host**
   - First, ensure the Hyper-V host (your Azure VM) is configured to allow these sessions.

    - Open Hyper-V Manager.

    - In the right-hand Actions pane, click Hyper-V Settings.

    - Under Server, select Enhanced Session Mode Policy and ensure Allow enhanced session mode is checked.

    - Under User, select Enhanced Session Mode and ensure Use enhanced session mode is checked.

    - Click OK.

Alternatively, run this in an elevated PowerShell on the Azure VM:

  ```PowerShell
  Set-VMHost -EnableEnhancedSessionMode $True
  ```
2. **Enable Guest Services on the Nested VM**
For the specific nested VM to accept the "handshake" for file and text transfer, Guest Services must be active.

    - Right-click your nested VM and select Settings.

    - In the left pane, under Management, select Integration Services.

    - Check the box for Guest services.

    - Ensure Clipboard is also checked (if visible).

    - Click Apply.

3. **Trigger the Connection**
When you click Connect to open the VM window, you should see a pop-up asking for the display resolution.

    - Click Show Options.

    - Go to the Local Resources tab.

    - Ensure Clipboard is checked.

    - Click Connect.

**Pro-Tip:** If you don't see the resolution pop-up, look at the top menu bar of the VM window. There is a small icon that looks like a computer with a spark/lightning bolt—this toggles Enhanced Session. If it’s greyed out, the Guest OS hasn't fully booted yet or Integration Services aren't running.


**Ref Link**:

- [YoutubeLink](https://www.youtube.com/watch?v=x4MMNESP6lw&list=PLJcpyd04zn7qjbnpZvN8RUt5nAqfetAea&index=15)


40:37

