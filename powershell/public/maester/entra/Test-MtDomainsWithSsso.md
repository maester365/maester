## Description

Executes KQL function over IdentityLogonEvents data to retrieve information about domains with Seamless SSO usage. It enriches the data with device insights.

## Why This Matters

Seamless Single Sign-On in Entra ID Connect should be disabled because:

- **Lateral movement**: Allows for lateral movement between an on-premise domain and Entra ID when an Entra ID Connect server is compromised.
- **Brute force**: Can be used for brute force attacks against Entra ID.

Seamless Single Sign-On is used for passwordless access for domain-joined devices, end-user devices, or device versions that do not support Primary Refresh Tokens (Windows versions prior to Windows 10 for example). This scenario is becoming less common, meaning most organizations should be able to disable SSSO in Entra ID Connect.

The output of the query should help you in identifying of SSSO usage is expected for the specific source device, based on device enrichment with MDE data.

#### Remediation action

There are two steps to disabling Seamless SSO, the first is to disable the configuration in Microsoft Entra Connect and the second is to tidy up Active Directory.

To disable the feature from Microsoft Entra connect, follow these steps:

1. Log-in to the computer running Microsoft Entra Connect Sync.
2. Click **Configure**.
3. Select **Change User Sign In** and click Next.
4. On the User **Sign-In section**, uncheck the **Enable single sign-on** box, click **Next**, then **Configure**.

Then to tidy up Active Directory you need to install and run the AzureADSSO PowerShell module, follow the steps below:

1. On an Active Directory management server, open PowerShell and run the following commands to install the AzureADSSO PowerShell module:

```powershell
#Install the AzureAD Module
install-module AzureAD

#Import the AzureAD SSO module
Import-Module "C:\program files\Microsoft Azure Active Directory Connect\AzureADSSO.psd1"
```

2. Then use the following commands to list all forests in your environment which have had Seamless SSO enabled: (if you have a single forest, you can move on to the next step).

```powershell
#Create an authentication context object for Azure AD
New-AzureADSSOAuthenticationContext

#Get the SSO status and domains from Entra ID
Get-AzureADSSOStatus
```

The output should contain `"enable":false`

3. Now you can tidy up your Active Directory by running the below commands to safely delete the AZUREADSSOACC if it is still present.

```powershell
#Store domain admin credentials
$creds = Get-Credential

#Disable SSO in the forest
Disable-AzureADSSOForest -OnPremCredentials $creds
```

To verify that Seamless SSO has been successfully disabled in your environment, start by signing in to the **Entra Admin portal** and expanding **Identity > Hybrid management** and select **Microsoft Entra Connect**. Then click **Connect Sync** and verify that Seamless single sign-on is set to Disabled. [You can also use this link to go to the Entra portal directly](https://entra.microsoft.com/#view/Microsoft_AAD_Connect_Provisioning/AADConnectMenuBlade/~/ConnectSync)

#### Related links

- [HybridBrothers hunting query](https://github.com/HybridBrothers/Hunting-Queries-Detection-Rules/blob/main/Entra%20ID/HuntDomainsWithSeamlessSsoEnabled.md)
- [Finding Seamless SSO usage](https://nathanmcnulty.com/blog/2025/08/finding-seamless-sso-usage/#)
- [Why you should disable Seamless SSO in Microsoft Entra Connect](https://ourcloudnetwork.com/why-you-should-disable-seamless-sso-in-microsoft-entra-connect/)
- [Advanced Active Directory to Entra ID lateral movement techniques](https://media.defcon.org/DEF%20CON%2033/DEF%20CON%2033%20presentations/Dirk-jan%20Mollema%20-%20Advanced%20Active%20Directory%20to%20Entra%20ID%20lateral%20movement%20techniques.pdf)