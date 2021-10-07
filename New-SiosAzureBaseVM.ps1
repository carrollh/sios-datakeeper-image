# New-SiosAzureBaseVM.ps1
# PS> .\New-SiosAzureBaseVM.ps1 -Product DKCE -Version 8.8.1 -OSVersion WS2019 -LicenseType PAYG -Verbose

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0)]
    [ValidateSet("SPSL","DKCE")]
    [String] $Product = '',

    [Parameter(Mandatory=$True, Position=1)]
    [String] $Version = '',

    [Parameter(Mandatory=$True, Position=2)]
    [ValidateSet("WS2012R2","WS2016","WS2019","RHEL79")]
    [String] $OSVersion = '',

    [Parameter(Mandatory=$True, Position=3)]
    [ValidateSet("BYOL","PAYG")]
    [String] $LicenseType = '',

    [Parameter(Mandatory=$False)]
    [ValidateSet('master','test','develop')]
    [String] $Branch = 'main',

    [Parameter(Mandatory=$False)]
    [Switch] $SAP = $False
)

function Get-ParametersFromURL() {
    Param(
        [Parameter(Mandatory=$False,Position=0)]
        [string] $URL
    )
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

# get parameters for template deployment
$parameterFilePath = "$($templateURLBase)/azuredeploy.parameters.json"
$resourcePrefix = "$($Product)v$($Version.Replace('.',''))-$($OSVersion)"
$parameters = Get-ParametersFromURL -URL $parameterFilePath
$parameters.networkInterfaceName.value = "$($resourcePrefix)-NIC"
$parameters.publicIpAddressName.value = "$($resourcePrefix)-IP"
$parameters.virtualMachineName.value = "$($resourcePrefix)"
$parameters.subscriptionId.value = (az account show | ConvertFrom-Json).id
$parameters.adminPassword.value = "SIOS!5105?sios"
$parameters.userData.value = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("echo 'userdata goes here' > C:\Windows\Temp\userdata.out"))

# format for verbose output
$parameters | Out-String -Stream | Write-Verbose

# format for azure cli acceptance
$params = ""
($parameters | Get-Member -MemberType NoteProperty).Name | foreach {
    $params += "$($_)=$($parameters.$_.value) "
}    

$templateURL += "$($templateURLBase)/azuredeploy.json"

Write-Verbose $templateURL
Write-Verbose $params

Write-Verbose "az deployment group create --resource-group AzurePublishing --template-uri $templateURL --parameters $params"
$output = az deployment group create --resource-group AzurePublishing --template-uri $templateURL --parameters $params

return $output
