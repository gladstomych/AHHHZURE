# Attack Path **SPOILERS BELOW**

The attack path is explained at the high level here with spoilers. In future, we may publish a blog post series for detailed walkthroughs on [JUMPSEC Labs](https://labs.jumpsec.com/)!
The Azure PowerShell & Az cli is recommended for most if not all of the steps. Additional tooling you might want to check out is listed below.

## Step 1 [variant b]
Enumerate for publicly exposed storage account with anonymous blob access enabled.

### Tools recommended:
- [Microburst](https://github.com/NetSPI/MicroBurst)

## Step 1 [variant a]
Gather a list of user emails. In real engagements this is done by OSINT techniques such as social media recon.
In this facitious tenant you may look at `users_no_spoiler.txt` to figure out what users there are, and use password spraying with weak password to get in.

### Tools recommended:
- [Msolspray](https://github.com/dafthack/MSOLSpray)
- [o365sprayer](https://github.com/securebinary/o365sprayer)

---

## Step 2
A Web Application resource is now discoverable in the [Azure portal](https://portal.azure.com) or CLI. (The app requires a user inside the tenant to access). 
There is a trivial RCE vuln in the application. With that you should be able to steal the App's access tokens via the IMDS service. 
Login as the application on Az PowerShell or cli.

### Tools recommended:
- [Burp Suite](https://portswigger.net/burp/communitydownload)

## Step 3
Enumerate for accessible resources as the application. The Web App should have access to a key vault and its secrets. 
Use either Az PowerShell or cli to access.

## Step 4
One of the secrets was a SAS URL of a private Azure blob storage container. Use the Azure Storage Explorer to access the storage container's contents.

### Tools recommended:
- [Azure Storage Explorer](https://azure.microsoft.com/en-us/products/storage/storage-explorer/)


## Step 5
Now a Linux VM should be discoverable either on the Azure portal or CLI. You may try to execute command or SSH into it, which you would find out that you don't have the permission to do so. How else to exploit your permissions? Try to do a custom script extension, and pop a shell on the VM. Try to find out what else there is on the machine.


# Visual Diagram

```
┌────────────┐
│ Password   │
│ Spray      │  appuser2
│ (weak pass)├──────────┐
│            │          │       ┌──────────────┐              ┌────────────┐
└────────────┘          │       │ Web App      │ [token via]  │ Key Vault  │
                        │[login]│ (link in     │   IMDS       │            │
                        ├──────►│  Az portal)  ├─────────────►│ with SAS   ├─────┐
                        │       │              │ RCE vuln     │ URL and    │     │
┌────────────┐          │       │ Req Azure    │              │            │     │
│ Public     │          │       │ auth for     │              │            │     │ SAS
│ Anonymous  ├──────────┘       │ Access       │              │            │     │ URL
│ Blob       │                  └──────────────┘              └────────────┘     │
│ (unauth)   │  appuser1.txt            in HTML                                  │
└────────────┘                                                                   │
                                                                                 │
                                                                                 ▼
                                            ┌───────────────┐         ┌────────────┐
                  ┌──────────┐              │  Sees Linux   │         │  Private   │
                  │          │[Custom script│  VM in portal │ [login] │  Storage   │
                  │  VM's    │ Ext RCE]     │               │         │  Container │
                  │  Home    │ ◄────────────┤  No command   │◄────────┤            │
                  │  Dir     │              │  Exec priv    │         │  (Blob2)   │
                  │          │              │               │         │            │
                  └──────────┘              │               │         └────────────┘
                    secret?                 │               │         VMOperator2.txt
                                            └───────────────┘       
               
```
