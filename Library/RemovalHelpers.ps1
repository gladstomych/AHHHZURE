#####################
# REMOVAL FUNCTIONS #
#####################


###################
# Resource Groups #
###################

function Remove-AhResourceGroups{

    Write-Output ("`n[i] Removing resource groups and associated resources.")
    foreach ($rgName in $resourceGroupNames) {
        # Check if the resource group exists
        $existingRG = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue

        if ($null -ne $existingRG) {
            # Delete the resource group
            $groupRemoved = Remove-AzResourceGroup -Name $rgName -Force 
            if ($groupRemoved -eq $True){
                Write-Output ("`t[+] Resource group {0} removed." -f $rgName)
            }
        }
    }

    $NWRGExist = Get-AzResourceGroup -Name "NetworkWatcherRG"
    if ($null -ne $NWRGExist){
        # Delete the NetworkWatcherRG 
        $groupRemoved = Remove-AzResourceGroup -Name "NetworkWatcherRG" -Force 
        if ($groupRemoved -eq $True){
            Write-Output ("`t[+] Resource group NetworkWatcherRG removed.")
        }
    }

}


######################
#       Users        #
######################

function Remove-AhUsers{
    # User removal
    Write-Output ("`n[i] Removing users and custom role(s).")

    # Removing the custom role assignment
    $CustomVMRoleAssignmentRemoved = (Get-AzRoleAssignment -RoleDefinitionName "VM Monitoring Operator" | Remove-AzRoleAssignment)
    # Removing the custom role definition
    $CustomVMRoleRemoved = (Get-AzRoleDefinition -Name "VM Monitoring Operator" | Remove-AzRoleDefinition -Force -PassThru)

    if ($null -ne $CustomVMRoleAssignmentRemoved -and $null -ne $CustomVMRoleRemoved){
        Write-Output("`t[+] Custom VM RBAC role removed from tenant.")
    }

    foreach ($line in Get-Content "$PSScriptRoot\Data\users.txt") {
        $parts = $line -split ':'
        $username = $parts[0]
    
        # Remove the Azure AD user
        $userRemoved = Remove-AzADUser -DisplayName $username -PassThru -ErrorAction SilentlyContinue
        if ($userRemoved -eq $True){
            Write-Output ("`t[+] User {0} removed." -f $username)
        }
    }

}


####################
# Storage Accounts #
####################

function Remove-AhStorageAccounts{
    Write-Host ("`n[i] Removing storage accounts.")
    $storageResourceGroupName = 'Backup'

    $script:stagingStorageAccountName = SanitizeStorageAccountName -AccountName $azureDomainName"staging"
    $script:adminStorageAccountName = SanitizeStorageAccountName -AccountName $azureDomainName"admin"
    $script:storageAccountNames = @($script:stagingStorageAccountName, $script:adminStorageAccountName)
    
    foreach ($accountName in $storageAccountNames) {
    
        # Check if the storage account exists
        $existingAccount = Get-AzStorageAccount -ResourceGroupName $storageResourceGroupName -Name $accountName -ErrorAction SilentlyContinue
    
        if ($null -ne $existingAccount) {
            Remove-AzStorageAccount -ResourceGroupName $storageResourceGroupName -Name $accountName -Force 
            Write-Output ("`t[+] Storage account {0} deleted." -f $accountName)

        } else {
            Write-Output ("[i] Storage account {0} not found." -f $accountName)
        }
    }
}


########################
#      Key Vaults      #
########################

function Remove-AhKeyVault {
    Write-Output "[i] Purging Keyvault."
    Remove-AzKeyVault -InRemovedState -Force -VaultName $script:keyVaultName -Location $Region -ErrorAction SilentlyContinue
    Write-Output "`t[+] Keyvault purge command sent."
}

##############################
#       Web Application      #
##############################

function Remove-AhAppRegistration {
    $AzADAppID = (Get-AzADApplication -DisplayNameStartWith "$script:azureDomainName").AppId
    if ($null -ne $AzADAppID){
        Remove-AzADApplication -ApplicationId $AzADAppID
        Write-Output "`t[+] Removed App registration."
    }
}


###################
# Virtual Machine #
###################

function Remove-AhVM {
    Write-Host ("`n[i] Removing VM and associated resources.")
    $publicIPName = "{0}-ip" -f $script:VMName

    $VMDeleted = Remove-AzVM -ResourceGroupName "Infra" -name $script:VMName -ForceDeletion $True -Force -ErrorAction SilentlyContinue
    if ($null -ne $VMDeleted){
        Write-Output ("`t[+] VM removed.")
    }
    Remove-AzNetworkSecurityGroup -Name $script:VMName -ResourceGroupName $script:resourceGroupNames[2] -Force -ErrorAction SilentlyContinue
    Remove-AzVirtualNetwork -Name $script:VMName -ResourceGroupName $script:resourceGroupNames[2] -Force -ErrorAction SilentlyContinue

    $PublicIpDeleted = Remove-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $script:resourceGroupNames[2] -Force -ErrorAction SilentlyContinue
    if ($null -ne $PublicIpDeleted){
        Write-Output ("`t[+] VM Public IP resource removed.")
    }
}