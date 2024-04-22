####################
# HELPER FUNCTIONS #
####################


function Assert-Condition {
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Condition,

        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage
    )

    if ($Condition) {
        Write-Error "Error. See output below for details."
        Write-Output "Error message: $ErrorMessage"
        Write-Output "For more information, run .\Install-VulnLab.ps1 -help`n"
        exit 1
    }
}


function Initialize-Script {
    # Check if TenantId and SubscriptionId are provided
    Assert-Condition -Condition ("" -eq $TenantId) -ErrorMessage "TenantId is required."
    Assert-Condition -Condition ("" -eq $SubscriptionId) -ErrorMessage "SubscriptionId is required."

    # Check if Az Powershell is installed
    Write-Output "[*] Initialising script"
    Write-Output "`n[i] Checking if Azure Powrshell is installed"
    $azureModule = Get-Module -Name Az.Accounts -ListAvailable
    Assert-Condition -Condition ($null -eq $azureModule) -ErrorMessage "Az Powershell Module not found. Visit https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows for more information."
    Write-Output "`t[+] Azure PowerShell is available."

    # Check if Az 
    Write-Output "`n[i] Checking if az cli is installed"
    $azCLI = Get-Command az 
    Assert-Condition -Condition ($null -eq $azCLI)  -ErrorMessage "Azure CLI (64-bit) version is not found. https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows for more information."
    Write-Output "`t[+] Azure CLI is installed."

    # Will pop up a Graphical login from the web
    Write-Output "`n[i] Connecting to specified Tenant."
    $AzPSConnection = Connect-AzAccount -TenantId $TenantId
    if ($null -ne $AzPSConnection){
        Write-Output "`t[+] Azure PowerShell Connection succeeded."
    }

    Write-Output "`n[i] Connecting to specified Tenant on az cli."
    $azCliLoginInfo = (az login --tenant $TenantId | ConvertFrom-Json)
    if ($null -ne $azCliLoginInfo.id){
        Write-Output "`t[+] Az Cli Connection succeeded."
    }

    # Set the context of the user's specified subscrition
    Write-Output "`n[i] Setting Cotext to specified subscription."
    $null = Set-AzContext -Subscription $SubscriptionId 
    Write-Output "`t[+] Context Set."

    # Check if the user has Global Admin rights over the subscription
    $subscriptionScope = "/subscriptions/$subscriptionId"
    $roleAssignments = Get-AzRoleAssignment -Scope $subscriptionScope 2>&1 3>&1

    Write-Output "`n[i] Checking if user is global admin."
    $hasGlobalAdmin = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq 'Owner' -and $_.Scope -eq $subscriptionScope }

    Assert-Condition -Condition ($null -eq $hasGlobalAdmin) -ErrorMessage "You must have Global Admin (Owner) rights over the subscription to proceed."
    $script:azureDomain = (Get-AzTenant -TenantId $TenantId).Domains
    $script:azureDomainName = $azureDomain -replace '\.onmicrosoft\.com$', ''
    Write-Output "`t[+] Global Admin Check succeeded!"


    # NOW we are authenticated with the correct permissions, we can create our resources n users.


    # A final warning before we begin
    Write-Warning "`nWe are about to make changes to resources in your Azure tenant: $azureDomain, $azureDomainName, in region: $Region"

    # Ask the user for confirmation
    $proceedConfirmation = Read-Host -Prompt "Are you sure you wish to proceed? (Y/n)"
    Assert-Condition -Condition ($proceedConfirmation -in @('N', 'n', 'No', 'NO', 'no')) -ErrorMessage "Resource creation aborted by the user."

    # need to register Microsoft.Storage if not done yet
    $storageProviderRegistered = (Get-AzResourceProvider -ProviderNamespace Microsoft.Storage | Where-Object RegistrationState -eq "Registered")

    if ( $null -eq $storageProviderRegistered ){
        Write-Output "`n[i] Detected that Microsoft.Storage provider has not been registered. This is the default state of a new tenant. Proceeding to registration which will take a minute."
        $registerProvider = Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
        Start-Sleep -Seconds 5

        While($True){
            $storageProviderRegistering = (Get-AzResourceProvider -ProviderNamespace Microsoft.Storage | Where-Object RegistrationState -eq "Registering")
            if ($null -ne $storageProviderRegistering){
                Write-Output "`t[i] Registering storage provider in progress... Automatically checking again in 10 seconds."
                Start-Sleep -Seconds 10
            }
            else {
                Write-Output "`t[i] Microsoft.Storage provider fully registered."
                break
            }
        }
    }

}

