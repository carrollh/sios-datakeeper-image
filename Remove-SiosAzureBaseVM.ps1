# Remove-SiosAzureBaseVM.ps1
# PS> .\Remove-SiosAzureBaseVM.ps1 -Product DKCE -Version 8.8.1 -OSVersion WS2019 -LicenseType PAYG -Branch develop -Verbose

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
    [ValidateSet('master','test','develop')]
    [String] $Branch = 'main',

    [Parameter(Mandatory=$False)]
    [Switch] $SAP = $False
)

### MAIN ##############################################################################
$resourcePrefix = "$($Product)v$($Version.Replace('.',''))-$($OSVersion)"
$vmName = $resourcePrefix.Replace('R2', '')
$nicName = "$($resourcePrefix)-NIC"
$ipName = "$($resourcePrefix)-IP"
$blob = "$($vmName)-C.vhd"

# delete VM
Write-Verbose "az vm delete --resource-group AzurePublishing --name $vmName ..."
az vm delete --resource-group AzurePublishing --name $vmName --yes

# delete C drive storage
Write-Verbose "az storage account show-connection-string --name azurepublishingdisks --query connectionString"
$connectionString = $(az storage account show-connection-string --name azurepublishingdisks --query connectionString)
Write-Verbose "az storage blob delete --delete-snapshots include --name $blob --container vhds --connection-string $connectionString"
az storage blob delete --delete-snapshots include --name $blob --container vhds --connection-string $connectionString 

# delete NIC
Write-Verbose "az network nic delete --resource-group AzurePublishing --name $nicName"
az network nic delete --resource-group AzurePublishing --name $nicName

#delete IP
Write-Verbose "az network public-ip delete --resource-group AzurePublishing --name $ipName"
az network public-ip delete --resource-group AzurePublishing --name $ipName
