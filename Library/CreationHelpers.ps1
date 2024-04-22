######################
# CREATION FUNCTIONS #
######################


###################
# Resource Groups #
###################

function Add-AhResourceGroups {
    Write-Output "`n[i] Creating Resource Groups"

    foreach ($rgName in $resourceGroupNames) {
        # Check if the resource group already exists in the selected region
        $existingRG = Get-AzResourceGroup -Name $rgName -Location $Region -ErrorAction SilentlyContinue
        Assert-Condition -Condition ($null -ne $existingRG) -ErrorMessage "Resource group $rgName already exists in $Region. Please choose a different name or delete the existing resource group."

        # Create the resource group in the selected region
        $rgCreated = New-AzResourceGroup -Name $rgName -Location $Region
        if ($null -ne $rgCreated){
            Write-Output ("`t[+] Resource group {0} created in {1}." -f $rgName, $Region)
        }
    }
    Write-Output "`t[+] Resource Groups Created."
}


######################
#       Users        #
######################

function Add-AhUsers{
    param(
        [Parameter(Mandatory=$true)]
        [string]$SubscriptionId, 

        [Parameter(Mandatory=$true)]
        [string]$VMResourceGroupName
    )


    Write-Output "`n[i] Users & Roles Creation"
    CreateVMOperatorRole 
    Write-Output "`n[i] Creating users."
    foreach ($line in Get-Content "$PSScriptRoot\Data\users.txt") {
        $parts = $line -split ':'
        $username = $parts[0]
        $password = $parts[1]
        $mailNickname = $parts[2]

        # Create the Azure AD user
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
        $userCreated = New-AzADUser -DisplayName $username -UserPrincipalName "$username@$azureDomain" -Password $securePassword -MailNickname $mailNickname
        $script:userlist += $userCreated

        if ($null -ne $userCreated){
            Write-Output ("`t[+] User {0} created." -f $username)
        }

        if ($userCreated.DisplayName -eq "John.Davis") {
            $subOwnerAssigned = New-AzRoleAssignment -ObjectId $userCreated.Id -RoleDefinitionName "Owner" -Scope "/subscriptions/$SubscriptionId"
            if ($subOwnerAssigned.RoleDefinitionName -eq "Owner"){
                Write-Output("`t[+] Additional role assigned for John Davis.")
            }
        }
        if ($userCreated.DisplayName -eq "Joseph.Davan") {
            $ErrorActionPreferenceBak = $ErrorActionPreference
            $ErrorActionPreference    = 'Stop'

            While($True){
                try{
                    AssignVMOperatorRole -UserId $userCreated.Id
                    break
                }
                catch{
                    Write-Output "`t[w] Custom Role assignment failed, this is not uncommon for Azure. Retrying in 1 second..."
                    Start-Sleep -Seconds 1 # wait for a second before the next attempt
                }
            }

            # Reset the ErrorActionPreference after exiting the loop
            $ErrorActionPreference = $ErrorActionPreferenceBak
        }
    }
} 

####################
# Storage Accounts #
####################

function Add-AhStorageAccounts{
    param(
        [Parameter(Mandatory=$true)]
        [string]$StorageResourceGroupName
    )

    Write-Output "`n[i] Creating storage acounts and populating with containers and blobs."

    $OneYearFromNow = (Get-Date).AddYears(1) 

    $script:stagingStorageAccountName = SanitizeStorageAccountName -AccountName $azureDomainName"staging"
    $script:adminStorageAccountName = SanitizeStorageAccountName -AccountName $azureDomainName"admin"
    $script:storageAccountNames = @($script:stagingStorageAccountName, $script:adminStorageAccountName)

    $testingStorageFiles = @('appuser1.txt','flag1.txt')
    $adminStorageFiles = @('vmoperator2.txt','flag4.txt')

    foreach ($accountName in $script:storageAccountNames) {
        # Storage account names must be between 3 and 24 characters in length and use numbers and lower-case letters only

        $StorageAccCreated = New-AzStorageAccount -ResourceGroupName $StorageResourceGroupName -Name $accountName -Location $Region -SkuName Standard_LRS -Kind StorageV2 -AllowBlobPublicAccess $true
        if ($null -ne $StorageAccCreated){
            Write-Output ("`t[+] Storage account {0} created." -f $accountName)
        }
        $Context = $StorageAccCreated.Context

        Write-Output ("`t[i] Waiting a minute to ensure the storage account can be accessed and populated...")
        Start-Sleep 60

        if ($accountName -Like "*admin*"){
            PopulateStorageAccount -ContainerName "vmops" -fileList $adminStorageFiles -StorageContext $Context
            $script:vmOpsContainerSAS = New-AzStorageContainerSASToken -Name "vmops" -Permission rwl -Context $Context -ExpiryTime $OneYearFromNow -FullUri 
        }
        elseif ($accountName -Like "*staging*"){
            # Allow anonymous listing & access
            PopulateStorageAccount -ContainerName "test" -fileList $testingStorageFiles -StorageContext $Context -AnonAccess
        }

    }
}

########################
#      Key Vaults      #
########################

function Add-AhKeyVault {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ApplicationResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]$keyVaultName
    )
    Write-Output "`n[i] Creating Key Vaults and populating with secrets."


    $script:sanitizedKeyVaultName = SanitizeKeyVaultName -KeyVaultName $keyVaultName

    $newVault = New-AzKeyVault -Name $script:sanitizedkeyVaultName -ResourceGroupName $ApplicationResourceGroupName -Location $Region
    if ($null -ne $newVault){
        Write-Output ("`t[+] Keyvault {0} created." -f $script:sanitizedKeyVaultName)
    }

    $SASUri = ConvertTo-SecureString $script:vmOpsContainerSAS -AsPlainText -Force

    $secret = Set-AzKeyVaultSecret -VaultName $script:sanitizedKeyVaultName -Name "VMOps-container-SAS" -SecretValue $SASUri

    $flag3 = ConvertTo-SecureString "{AHHHZURE_FL4G_3_U_ARE_THE_4PP_N0W_NEO}" -AsPlainText -Force
    $secret2 = Set-AzKeyVaultSecret -VaultName $script:sanitizedKeyVaultName -Name "Flag3" -SecretValue $flag3

    if ($null -ne $secret) {
        Write-Output("`t[+] SAS Uri written to Key Vault.")
    }
    if ($null -ne $secret2) {
        Write-Output("`t[+] Flag 3 written to Key Vault.")
    }

    $RBACEnabled = Update-AzKeyVault -ResourceGroupName $ApplicationResourceGroupName -VaultName $script:sanitizedKeyVaultName -EnableRbacAuthorization $true
    if ($null -ne $RBACEnabled){
        Write-Output ("`t[+] RBAC enabled for the created Key Vault.")
    }


}

##############################
#       Web Application      #
##############################

function Add-AhWebApp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ApplicationResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]$TenantId,

        [Parameter(Mandatory=$true)]
        [string]$SubscriptionId
    )
    Write-Output "`n[i] Creating Web App and associated App Service Plan. This will take a while..."

    Set-Location "$PSScriptRoot\Src"
    $appInfo = az webapp up --runtime "PHP:8.0" --os-type=linux --resource-group $ApplicationResourceGroupName `
        --sku Free --name $script:webAppName `
        --location $Region | ConvertFrom-Json
    
    $script:webAppURL = $appInfo.URL
    $script:webAppSvcPlan = $appInfo.appserviceplan
    $script:webAppDeployedName = $appInfo.name

    if ($null -ne $script:webAppURL){
        Write-Output ("`n`t[+] Web App successfully created. In a few minutes, it should be live at: `n`t`t{0}" -f $script:webAppURL)
    }
    Remove-Item ".\.azure" -Recurse -Force
    Set-Location "$PSScriptRoot\.."

    EnableAzLogin -TenantId $TenantId -resourceGroup $ApplicationResourceGroupName

    Write-Output "`n[i] Creating managed identity and granting access for vault."
    $ManagedIdentity = (az webapp identity assign -g $ApplicationResourceGroupName -n $script:webAppDeployedName | ConvertFrom-Json)
    if ($ManagedIdentity.type -eq "SystemAssigned"){
        Write-Output("`t[+] Managed identity created. ID: {0}" -f $ManagedIdentity.principalId)
    }
    $MIPrincipalId = $ManagedIdentity.principalId

    Write-Output("`t[i] Waiting a minute for the managed identity to be in effect in Azure...")
    Start-Sleep 60

    $keyVaultID = "/subscriptions/$SubscriptionId/resourceGroups/WebApp/providers/Microsoft.KeyVault/vaults/$script:sanitizedKeyVaultName"
    $roleReader = New-AzRoleAssignment -ObjectId $MIPrincipalId -RoleDefinitionName "Key Vault Reader" -Scope $keyVaultID
    $roleSecretUser = New-AzRoleAssignment -ObjectId $MIPrincipalId -RoleDefinitionName "Key Vault Secrets User" -Scope $keyVaultID
    if ($null -ne $roleReader -and $null -ne $roleSecretUser){
        Write-Output ("`t[+] Role assignments successful for the managed identity.")
    }

    $webAppScope = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Web/sites/{2}" `
        -f $SubscriptionId,$ApplicationResourceGroupName,$script:webAppDeployedName

    foreach ($UserInLoop in $script:userlist){
        if (($UserInLoop.DisplayName -eq "Jonathan.Doe") -or ($UserInLoop.DisplayName -eq "Jane.Donovan")){
            $roleUserReader = New-AzRoleAssignment -SignInName $UserInLoop.UserPrincipalName -Scope $webAppScope -RoleDefinitionName "Reader"

            if ($null -ne $roleUserReader){
                Write-Output("`t[+] Role assigned to {0}" -f $UserInLoop.DisplayName)
            }
        }
    }
}


###################
# Virtual Machine #
###################

function Add-AhVM {
 
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]$TenantId,

        [Parameter(Mandatory=$true)]
        [string]$SubscriptionId
    )
    $VMUserName = "ubuntu"
    $VMRandomPass = ( -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_}))
    $PSVMPassword = ConvertTo-SecureString $VMRandomPass -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential($VMUserName, $PSVMPassword)
    $publicIPName = "{0}-ip" -f $script:VMName

    Write-Output "`n[i] Creating VM and public IP address."

    $VMpublicIp = @{
        Name = $publicIPName
        ResourceGroupName = $VMResourceGroupName
        Location = $Region
        Sku = 'Standard'
        AllocationMethod = 'Static'
        IpAddressVersion = 'IPv4'
    }

   $DeployedVMPublicIp = New-AzPublicIpAddress @VMpublicIp
    if ($null -ne $DeployedVMPublicIp){
        Write-Output ("`t[+] Public IP resource created at {0}. VM will be accessible on this IP address." -f $DeployedVMPublicIp.IpAddress)
    }

    $VMprofile = @{
        ResourceGroupName = $VMResourceGroupName
        Location = $Region
        Name = $script:VMName
        PublicIpAddressName = $publicIPName
        Image = "Ubuntu2204"
        Size = "Standard_B1s"
        Credential = $psCred
    }

    Write-Output ("`t[i] Deploying Linux VM at B1 standard tier...")
    $VMCreated = New-AzVM @VMprofile

    if ($null -ne $VMCreated.VmId){
        $passFileContent = "Username: ubuntu, Password: {0} `nSSH Access: ssh ubuntu@{1}" -f $VMRandomPass, $DeployedVMPublicIp.IpAddress

        Write-Output("`t[+] VM created. Username: ubuntu, Password: [Hidden].") 
        Set-Content -Value $passFileContent -Path "$PSScriptRoot\Output\vm_pwd.txt"
        Write-Output("`t[+] Credentials saved to {0}\Output\vm_pwd.txt.`n`t[i] Note this is for debugging and is not part of the attack path." -f $PSScriptRoot)
    }

    # Configs, making sure that the disk and virtual network delete with the VM
    Write-Output("`t[i] Configuring VM...")
    $VMCreated.StorageProfile.OsDisk.DeleteOption = 'Delete'
    $VMCreated.StorageProfile.DataDisks | ForEach-Object { $_.DeleteOption = 'Delete' }
    $VMCreated.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.DeleteOption = 'Delete' }
    $VMUpdated = ($VMCreated | Update-AzVM)
    if ($VMUpdated.IsSuccessStatusCode -eq "True"){
        Write-Output("`t[+] VM Configuration done.")
    }

    $VMcmd = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroupName -Name $script:VMName -CommandId 'RunShellScript' -ScriptPath "$PSScriptRoot\vm_config.sh"
    if ($VMcmd.Status -eq 'Succeeded') {
        Write-Output ("`t[+] Bootstraping shell script successfully executed.")
    }
    
}


#########################
# Misc Helper functions #
#########################

function CreateVMOperatorRole {

    Write-Output "`n[i] Creating custom VM role."

    $jsonContent = Get-Content -Path "$PSScriptRoot\Data\role_definition.json" -Raw | ConvertFrom-Json
    # Getting a template from another role and scrubbing the contents
    $roleDefinition = Get-AzRoleDefinition -Name "Virtual Machine Contributor"
    $roleDefinition.Id = $null
    $roleDefinition.IsCustom = $True
    $roleDefinition.Actions.RemoveRange(0,$role.Actions.Count)

    $vmScope =  "/subscriptions/$SubscriptionId/resourceGroups/$VMResourceGroupName"

    # Assign properties from JSON
    $roleDefinition.Name = $jsonContent.Name
    $roleDefinition.Description = $jsonContent.Description
    $roleDefinition.Actions = $jsonContent.Actions
    $roleDefinition.NotActions = $jsonContent.NotActions
    $roleDefinition.AssignableScopes = $vmScope

    # Create the role definition in Azure
    
    $CustomRoleCreated = New-AzRoleDefinition -Role $roleDefinition
    if ($CustomRoleCreated.IsCustom -eq "True"){
        Write-Output "`t[+] Custom role created in the tenant."
    }

}

function AssignVMOperatorRole {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId
    )

    $vmScope =  "/subscriptions/$SubscriptionId/resourceGroups/$VMResourceGroupName"

    # Checking that the custom role exist
    while ($null -eq  (Get-AzRoleDefinition -Name "VM Monitoring Operator")) { 
        Write-Output "`t[i] New custom role not synchronised with the cloud yet, checking again in 5 seconds..."
        Start-Sleep -Seconds 5
    }

    # Assigning the role
    $CustomRoleAssigned = New-AzRoleAssignment -ObjectId $UserId -RoleDefinitionName "VM Monitoring Operator" -Scope $vmScope
    if ($CustomRoleAssigned.DisplayName -eq "Joseph.Davan"){
        Write-Output "`t[+] Custom role successfully assigned for Joseph Davan."
    }

}

function SanitizeKeyVaultName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyVaultName
    )

    $sanitized = ($KeyVaultName -replace '[^a-z0-9]', '').ToLower().Substring(0, [Math]::Min($KeyVaultName.Length, 16))
    $randID = (Get-Random -Maximum 9999).ToString()
    return ([String]::Concat($sanitized, $randID))
}

function SanitizeStorageAccountName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AccountName
    )

    # Sanitize the account name
    $sanitized = ($AccountName -replace '[^a-z0-9]', '').ToLower().Substring(0, [Math]::Min($AccountName.Length, 24))
    return $sanitized
}

function UploadBlob {
    param(
    [Parameter(Mandatory=$true)]
    [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IStorageContext]$StorageContext,

    [Parameter(Mandatory=$true)]
    [string]$ContainerName,

    [Parameter(Mandatory=$true)]
    [string]$BlobPath,

    [Parameter(Mandatory=$true)]
    [string]$BlobName
    )

    $Blob = @{
    File             = $BlobPath
    Container        = $ContainerName
    Blob             = $BlobName
    Context          = $StorageContext
    StandardBlobTier = 'Cool'
    }
    $uploadedBlob = Set-AzStorageBlobContent @Blob
    if ($null -ne $uploadedBlob){
        Write-Host "`t[+] Uploaded file: $BlobName."
    }
}

function PopulateStorageAccount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ContainerName,

        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IStorageContext]$StorageContext,
        
        [Parameter(Mandatory=$true)]
        [string[]]$fileList,

        [Parameter()]
        [switch]$AnonAccess
    )

    if ($AnonAccess){
        $ContainerCreated = New-AzStorageContainer -Name $ContainerName -Context $StorageContext -Permission Container
    }
    else {
        # Access restricted to owner
        $ContainerCreated = New-AzStorageContainer -Name $ContainerName -Context $StorageContext -Permission Off
    }

    if ($null -ne $ContainerCreated)
        {
            Write-Host "`t[+] Storage Container $ContainerName created."
        }

    foreach($filename in $fileList){
        UploadBlob -StorageContext $StorageContext -ContainerName $ContainerName -BlobName $filename -BlobPath "$PSScriptRoot\Data\$filename"
    }
}

function EnableAzLogin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantId,
        [Parameter(Mandatory=$true)]
        [string]$resourceGroup
    )

    Write-Output "`n[i] Enabling Authentication to Web App via Microsoft OAuth."

    $httpsAppURL = $script:webAppURL -replace "^http:", "https:"
    $issuerUrl = "https://login.microsoftonline.com/$TenantId/v2.0"
    $redirectURL = "{0}/.auth/login/aad/callback" -f $httpsAppURL
    $appServiceName = $script:webAppDeployedName
    $appRegistrationName = $script:webAppDeployedName
    $homepageUrl = $httpsAppURL

    # Creating the Entra ID App registration
    $appRegistration = (az ad app create --display-name $appRegistrationName --web-home-page-url $homepageUrl `
        --query "{appId: appId, objectId: objectId}" --enable-access-token-issuance true --enable-id-token-issuance true `
        --web-redirect-uris $redirectURL | ConvertFrom-Json)
    $appRegistrationClientId = $appRegistration.appId

    if ($null -ne $appRegistrationClientId){
        Write-Output ("`t[+] App registration creation successful. ID: {0}" -f $appRegistrationClientId)
    }

    # Creating the App Secret, which will expire in a year
    $endDate = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $appRegistrationClientSecret = (az ad app credential reset --id $appRegistrationClientId --append --end-date $endDate --query "password" -o tsv)

    if ($null -ne $appRegistrationClientSecret){
        Write-Output ("`t[+] App client secret creation successful.")
    }

    # Upgrading Auth version to V2
    $v2upgraded = (az webapp auth config-version upgrade --name $appServiceName --resource-group $resourceGroup | ConvertTo-Json)
    if ($null -ne $v2upgraded) {
        Write-Output "`t[+] Authentication for Web App upgraded to V2."
    }

    # Enabling MS as an ID provider for the App
    $idProviderEnabled = (az webapp auth microsoft update  -g $resourceGroup --name $appServiceName `
        --client-id $appRegistrationClientId --client-secret $appRegistrationClientSecret --issuer $issuerUrl -y | ConvertFrom-Json)
    if ($null -ne $idProviderEnabled.enabled) {
        Write-Output ("`t[+] MS as identity provider enabled.")
    }
    

    # Enabling auth via the configured ID provider and redirect access to Az login
    $authUpdated = (az webapp auth update -g  $resourceGroup --name $appServiceName --unauthenticated-client-action RedirectToLoginPage  --enabled true | ConvertFrom-Json)
    if ($null -ne $authUpdated.globalValidation) {
        Write-Output ("`t[+] Authenticated via the identity provider enabled. Now the app requires Azure login in the tenant to access!")
    }
}