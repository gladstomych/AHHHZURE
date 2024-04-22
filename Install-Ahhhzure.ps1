<#
.SYNOPSIS
This script deploys an intentionally vulnerable Azure environment for learning and practicin offensive TTPS in an Azure environment.

.DESCRIPTION
Install-VulnLab.ps1 sets up a vulnerable Azure lab environment for security professionals to explore and learn various Azure attack techniques. The script creates users, a Linux VM, a web app, a keyvault, and storage accounts, spread over 4 resource groups.

.PARAMETER TenantId
The Azure Tenant ID where the resources will be deployed.

.PARAMETER SubscriptionId
The Azure Subscription ID where the resources will be deployed.

.PARAMETER Help
Displays this help message.

.PARAMETER TearDown
(Optional) Procedurally remove user and resource deployed. Recommended for cleanup and troubleshooting.

.EXAMPLE
path\to\Install-VulnLab.ps1 -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id" -All
# This deploys the environment

PS C:\> path\to\Install-VulnLab.ps1 -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"
# This runs the pre-deployment checks and nothing else

PS C:\> path\to\Install-VulnLab.ps1 -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id" -TearDown

# This tears down everything

.NOTES
- Ensure you have the necessary permissions (recommended: Global Admin) in your Azure tenant.
- Do not use it for production or store sensitive data.
- Powershell Az module is required - visit https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows for more information.

.LINK
https://github.com/gladstomych/AHHHZURE

#>

param(
    [string]$TenantId = "",
    [string]$SubscriptionId = "",
    [string]$Region = "UK South",
    [switch]$Help,
    [switch]$TearDown,
    [switch]$All,
    [switch]$RG,
    [switch]$User,
    [switch]$KeyVault,
    [switch]$Storage,
    [switch]$WebApp,
    [switch]$VM,
    [switch]$Test
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    exit
}

$asciiBanner = @'
                                            #                                                          
                                             ##                                                        
                                             ###                                                      
      *\      **     **\ **     **\ **        ###    **\    **\ *******\  *******\                   
     ***\     **     ** |**     ** |**        #####  ** |   ** |**    **| \_______|
    ** **\    **     ** |**     ** |**    ###########       ** |**   ***|
   **   **\   ********* |********* |******* ###########     ** |******* | ******\                     
  **     **\  **  ___** |**  __ ** |**  __ *  ####   ** |   ** |**  ***/  **  ___|                       
 **  *******\ ** |   ** |** |   ** |** |   **  ####  ** |   ** |** |\**\  ** |                         
**  ____ *** |** |   ** |** |   ** |** |   **    ##   *******  |** | \**\ *******\                    
\_/      \___|\__|   \__|\__|   \__|\__|   \_     ##  \_______/ \__|  \__|\_______|                                  
                                                   #                                              
                                                    #                                                
'@

Write-Output $asciiBanner

#############################
# Sourcing helper functions #
############################# 

. $PSScriptRoot\Library\CreationHelpers.ps1
. $PSScriptRoot\Library\GeneralHelpers.ps1
. $PSScriptRoot\Library\RemovalHelpers.ps1
# . $PSScriptRoot\Library\TestHelpers.ps1


############################################
# Temporarily disable those pesky warnings #
############################################

Update-AzConfig -DisplayBreakingChangeWarning $false -Scope Process | Out-Null
az config set extension.use_dynamic_install=yes_without_prompt


#####################################################
# Initialization such as login, setting context etc #
#####################################################

Initialize-Script


###############
# Global Vars #
###############

$script:resourceGroupNames = @('WebApp', 'Backup', 'Infra')
$keyVaultName = "appvault$azureDomainName"
$script:webAppName = "$azureDomainName-internal-app"
$script:VMName = "$azureDomainName-infra-vm"
$script:userlist = [System.Collections.Generic.List[string]]::new() 
$currentUsers = Get-AzADUser
$script:userlist += $currentUsers


####################
# Resource Toggles #
####################

if ($All){
    $RG = $True
    $User = $True
    $KeyVault = $True
    $Storage = $True
    $WebApp = $True
    $VM = $True
}

# what resources are included in test
# if ($Test){ }


#################################
# Tear down specified resources #
#################################

if ($TearDown) {
    Write-Output "[i] Tearing Down specified resources..."

    if ($User){Remove-AhUsers}
    if ($Storage){Remove-AhStorageAccounts}
    if ($VM){Remove-AhVM}
    if ($WebApp){Remove-AhAppRegistration}
    if ($RG){Remove-AhResourceGroups}
    if ($KeyVault){Remove-AhKeyVault}
    exit
} 

##############################
# Deploy specified resources #
##############################

else {

    if ($RG){Add-AhResourceGroups}
    if ($User){Add-AhUsers -SubscriptionId $SubscriptionId -VMResourceGroupName "Infra"}
    if ($Storage){Add-AhStorageAccounts -StorageResourceGroupName "Backup"}
    if ($KeyVault){Add-AhKeyVault -ApplicationResourceGroupName "WebApp" -KeyVaultName $keyVaultName}
    if ($WebApp){Add-AhWebApp -ApplicationResourceGroupName "WebApp" -TenantId $TenantId -SubscriptionId $SubscriptionId}
    if ($VM){Add-AhVM -VMResourceGroupName "Infra" -TenantId $TenantId -SubscriptionId $SubscriptionId}
    # Custom Testing stuff
    # if ($Test){ }
}