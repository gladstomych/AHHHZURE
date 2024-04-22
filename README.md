![Project Logo](screenshots/logo.png)

# Introduction
AHHHZURE is an automated vulnerable Azure deployment script designed for offensive security practitioners and enthusiasts to brush up their cloud sec skills. The lab has 5 flags in total to collect. You may start completely without assistance if you are experienced, or start with the `no spoiler` hints if Azure cloud sec is quite new to you. In future, we are planning to publish a blog post series for detailed walkthroughs on [JUMPSEC Labs](https://labs.jumpsec.com/).

This lab is practically free to run **in the first 30 days**, going well below a new Azure account's *free credits* provided by MS on sign up ($200 as of early 2024). After the first month, you may either choose to switch to a pay-as-you-go plan, or opt to freeze the paid elements. Continuing to run the lab instance as-is with pay-as-you-go, would cost single digit of USDs per month. The environment is designed to be as "one-click install" as possible and there is a small number of requirements as outlined below. 

**Tip:** To save money after the free month: `-TearDown` the instance when you are not using it for an extended period, and redeploying the environment when tackling the lab again.

## Target Audience
- Pentester / Cloud engineer / Cloud Sec enthusiast who wants to get into Azure security
- Difficulty - beginner facing
- Specific pre-requisite skills - Some familiarity with PowerShell is good to have. Some experience with another cloud cli would help but not a must
- Walkthrough / Hints - Detailed walkthroughs are on my todo list, keep an eye out for [JUMPSEC Labs](https://labs.jumpsec.com/) if you are interested. For now, there are hints, either spoiler or spoiler-free in the repo.

## Installation & Removal
### Requirements
- Windows Machine/VM with PowerShell version 5 or above.
- Azure (Az) PowerShell Module. See [installing Az PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell).
- Az cli (**64-bit version**) for Windows, version >= 2.12.0. See [installing Az cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows).
- An Azure Tenant that you own.

Check out the [detailed instructions](./detailed_instructions.md) if you are not sure about any of the above. The script checks for the requirements and would exit automatically if they were not met.

### Using the Script to Deploy Resources

After installing the required components above and having set up your own Azure tenant, clone this repo onto your local machine and `cd` into the cloned directory. The script has two mandatory flags: `-TenantId` and `-SubscriptionId`. These flags specify the tenant and subscription where resources will be deployed or removed. Refer to [detailed instructions](./detailed_instructions.md) for a guide to set up a tenant and find those IDs. To deploy everything in one go (which is the recommended way to deploy), use the `-All` flag. This process can take between 15-20 minutes due to the time required for cloud resources to initialize and be configured. 

```PowerShell
git clone https://github.com/gladstomych/AHHHZURE.git
cd AHHHZURE

# You will be prompted to log into your Azure tenant. Log in as the Tenant Owner / Global Admin and provide additional confirmations as required.
.\Install-Ahhhzure.ps1 -TenantId "my-tenant-id" -SubscriptionId "my-subscription-id" -All
```

Running the script without the `-All` or additional `-<Resouce>` flags would not deploy or remove any resources. The script would check if the requirements are met and then exit. You may also specify the region to deploy with an optional `-Region "<region>"` flag. If unspecified, the script defaults to `UK South`. See available Azure regions in detailed instructions.

### Cleanup
To remove resources, pass the `-TearDown` flag. For removing all resources, the recommended method is to use `-TearDown` with the `-All` flag:

```PowerShell
# This typically takes 3-5 minutes
.\Install-Ahhhzure.ps1 -TenantId "my-tenant-id" -SubscriptionId "my-subscription-id" -TearDown -All
```

**Note**: Like deployment, not specifying any resource flag or `-All` will result in no change being made to your tenant. While it is possible to remove individual resources, the `-All` flag is recommended.

## Hints
Stepwise hints that are spoiler free can be found in the [spoiler_free](./Hints/spoiler_free) folder. There is also [spoiler](./Hints/spoiler) hints in the other folder if you are stuck. 


## Troubleshooting
If you are sure all the requirements are met but errors arise during deployments, try to `-TearDown -All` and to run the deployment script again. This typically solves most issues you may encounter. See detailed instructions on specific areas and resource interdependencies. If you installed 32-bit version of Azure cli, you'd see a number of non-breaking warning about python cryptography. This does not affect the functionality of the deployed environment.

## Disclaimer
Everything provided in this repository is as is, with no guarantee of support if things do not work as intended. We tried our best to make the deploy script as verbose and automated as possible but there is a possibility that you might need to take it apart to debug some errors in your own environment. As Azure and Azure PowerShell module changes, we will try our best to maintain compatibility. Please raise issues with error messages for issues you may encounter during installation. 

Materials provided are for educational purposes only and you are responsible for your own actions. The resources deployed from the script is intentionally vulnerable so please do not run production workload on the same tenant.

## License
GPLv3
