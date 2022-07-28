<#
.Description
Creates a vm image from an existing generalized vm.
.EXAMPLE
PS> .\New-SiosAzureImage.ps1 -Product DKCE -Version 8.8.2 -OSVersion WS2012R2 -LicenseType BYOL -Verbose
.EXAMPLE
PS> .\New-SiosAzureImage.ps1 -Product DKCE -Version 8.8.2 -OSVersion WS2019 -LicenseType PAYG -Verbose
.SYNOPSIS
Used to create a VM image that will become a new version of one of SIOS' Azure Marketplace VM offerings.
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

$versionSKUs = @{
    "WS2012R2" = "2012-R2";
    "WS2016" = "2016";
    "WS2019" = "2019";
    "WS2022" = "2022";
}

### MAIN ##############################################################################
Write-Verbose "Starting $tag Image creation process..."

$credential = Get-Credential
Connect-AzAccount -Credential $credential
Select-AzSubscription -SubscriptionName 'Visual Studio Premium with MSDN'

$vmName = "$($Product)$($Version.Replace('.',''))$($OSVersion.Replace('WS','').Replace('R2',''))$($LicenseType)"
$rgName = 'AzurePublishing'
$location = "EastUS"
$imageName = "$($Product.Replace('DKCE','DK'))v$($Version.Replace('.',''))on$($OSVersion.Replace('WS',''))$($LicenseType)"
Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force
Set-AzVm -ResourceGroupName $rgName -Name $vmName -Generalized

$vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName
$image = New-AzImageConfig -Location $location -SourceVirtualMachineId $vm.Id

Write-Verbose $vmName
Write-Verbose $rgName
Write-Verbose $location
Write-Verbose $imageName

New-AzImage -Image $image -ImageName $imageName -ResourceGroupName $rgName
