<#
.Description
Simple deployment script for a VM into the AzurePublishing resource group.
.EXAMPLE
PS> .\New-SiosAzureBaseVM.ps1 -Product DKCE -Version 8.8.2 -OSVersion WS2012R2 -LicenseType BYOL -Verbose
.EXAMPLE
PS> .\New-SiosAzureBaseVM.ps1 -Product DKCE -Version 8.8.2 -OSVersion WS2019 -LicenseType PAYG -Verbose -SAP
.SYNOPSIS
Used to deploy and configure VM that will become a new version of one of SIOS' Azure Marketplace VM offerings.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0)]
    [ValidateSet("SPSL","DKCE")]
    [String] $Product = '',

    [Parameter(Mandatory=$True, Position=1)]
    [String] $Version = '',

    [Parameter(Mandatory=$True, Position=2)]
    [ValidateSet("WS2012R2","WS2016","WS2019","WS2022","RHEL79")]
    [String] $OSVersion = '',

    [Parameter(Mandatory=$True, Position=3)]
    [ValidateSet("BYOL","PAYG")]
    [String] $LicenseType = '',

    [Parameter(Mandatory=$False)]
    [ValidateSet('main','test','develop')]
    [String] $Branch = 'main',

    [Parameter(Mandatory=$False)]
    [Switch] $SAP = $False
)

function Get-ParametersFromURL() {
    Param(
        [Parameter(Mandatory=$False,Position=0)]
        [string] $URL
    )
    Write-Verbose "Downloading $URL"
    return ((Invoke-WebRequest -Uri $URL).Content | ConvertFrom-Json).parameters
}

function Get-ParametersFromFile() {
    Param(
        [Parameter(Mandatory=$False,Position=0)]
        [string] $Path
    )
    return (Get-Content $Path | Out-String | ConvertFrom-Json).parameters
}

if ( $OutDir -eq $Null -Or $OutDir -eq "" ) {
    $OutDir = $PSScriptRoot
}

### Parameter validation - START
$parametersAreValid = $True

if ( $SAP ) {
    if ( $LicenseType -eq 'BYOL' ) {
        Write-Error "`nSAP AMIs only support PAYG license model."
        $parametersAreValid = $false
    }

    if ( $OSVersion -eq 'WS2012R2' ) {
        Write-Error "`nSAP AMIs are only supported on WS2016+."
        $parametersAreValid = $false
    }
}
if(-Not $parametersAreValid) {
    return 1
}
### Parameter validation - END

### MAIN ##############################################################################
$templateURLBase = "https://raw.githubusercontent.com/carrollh/sios-datakeeper-image/$($Branch)"

if ( $SAP ) {
    $tag = "$($Product)v$($Version.Replace('.',''))forSAPon$($OSVersion.Replace('WS',''))-$($LicenseType)"
}
else {
    $tag = "$($Product)v$($Version.Replace('.',''))on$($OSVersion.Replace('WS',''))-$($LicenseType)"
}
Write-Verbose "Starting $tag Image creation process..."

# lookup who the user is running this script
$qaUser = & "whoami"
$qaUser = $qaUser.ToUpper().Replace("STEELEYE\",'')

$versionSKUs = @{
    "WS2012R2" = "2012-R2";
    "WS2016" = "2016";
    "WS2019" = "2019";
    "WS2022" = "2022";
}

# get parameters for template deployment
$parameterFilePath = "$($templateURLBase)/azuredeploy.parameters.json"
$resourcePrefix = "$($Product)v$($Version.Replace('.',''))-$($OSVersion.Replace('R2', ''))"
$parameters = Get-ParametersFromURL -URL $parameterFilePath

$parameters.adminPassword.value = "SIOS!5105?sios"
$parameters.branch.value = $Branch
$parameters.dkVersion.value = $Version
$parameters.licenseType.value = $LicenseType
$parameters.networkInterfaceName.value = "$($resourcePrefix)-NIC"
$parameters.osVersion.value = $versionSKUs["$OSVersion"]
$parameters.publicIpAddressName.value = "$($resourcePrefix)-IP"
$parameters.subscriptionId.value = (az account show | ConvertFrom-Json).id
$parameters.virtualMachineName.value = $resourcePrefix

# format for verbose output
$paramNames = ($parameters | Get-Member -Type NoteProperty).Name
$paramNames | foreach {
    $msg = "$_"
    Write-Verbose ($msg.PadRight(22,' ') + ": " + $parameters.($_).value)
}

# format for azure cli acceptance
$params = '{ \"' + $paramNames[0] + '\": {\"value\":\"' + $parameters.($paramNames[0]).value + '\"}'
for($i = 1; $i -lt $paramNames.Count; $i++) {
    $params += ', \"' + $paramNames[$i] + '\": {\"value\":\"' + $parameters.($paramNames[$i]).value + '\"}'
}
$params += ' }'

$templateURL += "$($templateURLBase)/azuredeploy.json"

Write-Verbose $templateURL

Write-Verbose "az deployment group create --resource-group AzurePublishing --template-uri $templateURL --parameters $params"
az deployment group create --resource-group AzurePublishing --template-uri $templateURL --parameters $params
