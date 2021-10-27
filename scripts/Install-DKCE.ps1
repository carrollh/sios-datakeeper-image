[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [string]$IssSource = 'https://quickstart-sios-amis.s3.amazonaws.com/main/iss/',

    [Parameter(Mandatory=$False)]
    [string]$SWVersion = '8.8.1',

    [Parameter(Mandatory=$False)]
    [Switch]$AMI = $False
)

$exeUrls = [ordered]@{
    '8.6.4' = '8.6.4/DataKeeperv8.6.4-2360/DK-8.6.4-Setup.exe';
    '8.7.1' = '8.7.1/DataKeeperv8.7.1-598277/DK-8.7.1-Setup.exe';
    '8.7.2' = '8.7.2/DataKeeperv8.7.2-965453/DK-8.7.2-Setup.exe';
    '8.8.0' = '8.8.0/DataKeeperv8.8.0-1252298/DK-8.8.0-Setup.exe';
    '8.8.1' = '8.8.1/DataKeeperv8.8.1-1442260/DK-8.8.1-Setup.exe';
}

$exeSource = 'http://e512b7db7365eaa2f93b-44b251abad247bc1e9143294cbaa102a.r50.cf5.rackcdn.com/windows/SIOS_DataKeeper_Windows_en_'
$exeUrl = ""
if($SWVersion -like "latestbuild") {
    $exeUrl = 'https://sios-automation.s3.amazonaws.com/dk/DKSetup.exe'
}
else {
    $exeUrl = [string]$exeSource + $exeUrls[$SWVersion]
}
$exeFile = 'C:\cfn\downloads\DKSetup.exe'

$issUrl = ''
if ( $AMI ) {
    $issUrl = [string]$IssSource + "setupAMI-$SWVersion.iss"
}
else {
    $issUrl = [string]$IssSource + "setup-$SWVersion.iss"
}
$issFile = 'C:\cfn\downloads\setup.iss'

try {
    $ErrorActionPreference = "Stop"

    $parentDir = Split-Path $ExeFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType directory -Force | Out-Null
    }

    $tries = 5
    while ($tries -ge 1) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            Write-Verbose "Trying to download from $exeUrl"
            (New-Object System.Net.WebClient).DownloadFile($exeUrl,$exeFile)

            Write-Verbose "Trying to download from $issUrl"
            (New-Object System.Net.WebClient).DownloadFile($issUrl,$issFile)
            break
        }
        catch {
            $tries--
            Write-Verbose "Exception:"
            Write-Verbose "$_"
            if ($tries -lt 1) {
                throw $_
            }
            else {
                Write-Verbose "Failed download. Retrying again in 5 seconds"
                Start-Sleep 5
            }
        }
    }

    if ([System.IO.Path]::GetExtension($exeFile) -eq '.exe') {
        & "$exeFile" /s /w /f1$issFile /f2C:\cfn\downloads\setup.log | Out-Null # wait for setup to end
    } else {
        throw "Unsupported file extension"
    }
}
catch {
    $_
}
