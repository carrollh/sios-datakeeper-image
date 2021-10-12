# Set-DKCEImageConfig.ps1
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0)]
    [ValidateSet("WS2012R2","WS2016","WS2019","WS2022","RHEL79")]
    [String] $OSVersion = '',

    [Parameter(Mandatory=$True, Position=1)]
    [ValidateSet("BYOL","PAYG")]
    [String] $LicenseType = ''
)

# Configure Local Security Policies
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "EveryoneIncludesAnonymous" -Value 1
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" -Name "RestrictNullSessAccess" -Value 0

# Exclude DKCE Path from Defender
if(-Not ($OSVersion -like "WS2012*")) {
    Set-MpPreference -ExclusionPath "C:\Program Files(x86)\SIOS"
} 

# Disable Automatically Managed Pagefiles Setting
$sys = Get-WmiObject Win32_Computersystem –EnableAllPrivileges
$sys.AutomaticManagedPagefile = $false
$sys.put()

# Create Shortcut to DKCE on Desktop
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Administrator\Desktop\DataKeeper.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\SIOS\DataKeeper\DataKeeper.msc"
$Shortcut.Save()

# Set Instance Storage Volume Pagefile to System Managed
Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="D:\pagefile.sys"; InitialSize = 0; MaximumSize = 0} -EnableAllPrivileges | Out-Null

# Set BitmapBaseDir to Instance Storage Drive
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\ExtMirr\Parameters" -Name "BitmapBaseDir" -Value "D:\"
if($LicenseType -like 'PAYG') {
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{71a27cdd-812a-11d0-bec7-08002be2092f}" -Name "ClassMask" -PropertyType "DWord" -Value 0 -Force
}