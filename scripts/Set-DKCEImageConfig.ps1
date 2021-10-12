# Set-DKCEImageConfig.ps1
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0)]
    [ValidateSet('2012','2016','2019','2022')]
    [String] $OSVersion = '',

    [Parameter(Mandatory=$True, Position=1)]
    [ValidateSet('BYOL','PAYG')]
    [String] $LicenseType = ''
)

$logFile = "C:\cfn\logs\Set-DKCEImageConfig.ps1.txt"
"START Set-DKCEImageConfig.ps1" | Out-File -Encoding ascii -FilePath $logFile

Try {
    # Configure Local Security Policies
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name EveryoneIncludesAnonymous -Value 1 | Out-File -Encoding ascii -FilePath $logFile -Append
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name RestrictNullSessAccess -Value 0 | Out-File -Encoding ascii -FilePath $logFile -Append

    # Exclude DKCE Path from Defender
    if(-Not ($OSVersion -like "2012")) {
        Set-MpPreference -ExclusionPath 'C:\Program Files(x86)\SIOS' | Out-File -Encoding ascii -FilePath $logFile -Append
    } 

    # Disable Automatically Managed Pagefiles Setting
    $sys = Get-WmiObject Win32_Computersystem -EnableAllPrivileges
    $sys.AutomaticManagedPagefile = $false
    $sys.put() | Out-File -Encoding ascii -FilePath $logFile -Append

    # Create Shortcut to DKCE on Desktop
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("C:\Users\$($env:username)\Desktop\DataKeeper.lnk")
    $Shortcut.TargetPath = 'C:\Program Files (x86)\SIOS\DataKeeper\DataKeeper.msc'
    $Shortcut.Save()

    # Set Instance Storage Volume Pagefile to System Managed
    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name='D:\pagefile.sys'; InitialSize = 0; MaximumSize = 0} -EnableAllPrivileges | Out-File -Encoding ascii -FilePath $logFile -Append

    # Set BitmapBaseDir to Instance Storage Drive
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\ExtMirr\Parameters' -Name BitmapBaseDir -Value 'D:\' | Out-File -Encoding ascii -FilePath $logFile -Append
    if($LicenseType -like 'PAYG') {
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{71a27cdd-812a-11d0-bec7-08002be2092f}' -Name ClassMask -PropertyType DWord -Value 0 -Force | Out-File -Encoding ascii -FilePath $logFile -Append
    }
}
Catch {
    $_ | Out-File -Encoding ascii -FilePath $logFile -Append
}

"END Set-DKCEImageConfig.ps1" | Out-File -Encoding ascii -FilePath $logFile -Append