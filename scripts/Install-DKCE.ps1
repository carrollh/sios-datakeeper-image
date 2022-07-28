[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [string]$IssSource = 'https://quickstart-sios-amis.s3.amazonaws.com/main/iss/',

    [Parameter(Mandatory=$False)]
    [string]$SWVersion = '8.9.0'
)

$timestamps = [ordered]@{
    '8.3.0' = '1791';
    '8.4.0' = '1995';
    '8.5.0' = '2107';
    '8.6.0' = '2198';
    '8.6.1' = '2219';
    '8.6.2' = '2277';
    '8.6.3' = '2323';
    '8.6.4' = '2360';
    '8.6.5' = '2383';
    '8.7.0' = '2391';
    '8.7.1' = '598277';
    '8.7.2' = '965453';
    '8.8.0' = '1252298';
    '8.8.1' = '1499799';
    '8.8.2' = '1557552';
    '8.9.0' = '1834023'
}

$exeSource = 'http://e512b7db7365eaa2f93b-44b251abad247bc1e9143294cbaa102a.r50.cf5.rackcdn.com/windows/SIOS_DataKeeper_Windows_en_'
$exeUrl = ""
if($SWVersion -like "latestbuild") {
    $exeUrl = 'https://sios-automation.s3.amazonaws.com/dk/DKSetup.exe'
}
else {
    $exeUrl = "$($exeSource)$($SWVersion)/DataKeeperv$($SWVersion)-$($timestamps[$SWVersion])/DK-$($SWVersion)-Setup.exe";
}

$exeFile = 'C:\cfn\downloads\DKSetup.exe'
$issUrl = "$($IssSource)setupAMI-$($SWVersion).iss"
$issFile = 'C:\cfn\downloads\setup.iss'

try {
    if (-Not (Test-Path 'C:\cfn\log') ) {
        New-Item -Type Directory 'C:\cfn\log' -Force
    }
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ErrorActionPreference = "Stop"

    $parentDir = Split-Path $ExeFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType directory -Force | Out-Null
    }

    $tries = 5
    while ($tries -ge 1) {
        try {
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
        & "$exeFile" /s /f1$issFile /f2C:\cfn\log\setupDK.log
        #Start-Process -FilePath wusa.exe -ArgumentList $Destination,'/quiet','/norestart' -Wait
    } else {
        throw "Unsupported file extension"
    }
    Start-Sleep 120
}
catch {
    $_
}
