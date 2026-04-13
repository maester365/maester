2.1.7 (L1) Ensure that an anti-phishing policy has been created

By default, Office 365 includes built-in features that help protect users from phishing attacks. Set up anti-phishing polices to increase this protection, for example by refining settings to better detect and prevent impersonation and spoofing attacks. The default policy applies to all users within the organization and is a single view to fine-tune antiphishing protection. Custom policies can be created and configured for specific users, groups or domains within the organization and will take precedence over the default policy for the scoped users.

#### Rationale

Protects users from phishing attacks (like impersonation and spoofing) and uses safety tips to warn users about potentially harmful messages.

#### Impact

Mailboxes that are used for support systems such as helpdesk and billing systems send mail to internal users and are often not suitable candidates for impersonation protection. Care should be taken to ensure that these systems are excluded from Impersonation Protection.

#### Remediation action:

1. Navigate to [Microsoft 365 Defender](https://security.microsoft.com)
2. Click to expand **Email & collaboration** select **Policies & rules**
3. Select **Threat policies**.
4. Under Policies select **Anti-phishing** and click **Create**.
5. Name the policy, continuing and clicking **Next** as needed:
* Add **Groups** and/or **Domains** that contain a majority of the organization.
* Set **Phishing email threshold** to **3 - More Aggressive**
* Check **Enable users to protect** and add up to 350 users.
* Check **Enable domains to protect** and check **Include domains I own**.
* Check **Enable mailbox intelligence (Recommended)**.
* Check **Enable Intelligence for impersonation protection (Recommended)**.
* Check **Enable spoof intelligence (Recommended)**.
1. Under Actions configure the following:
* Set **If a message is detected as user impersonation to Quarantine the message**.
* Set **If a message is detected as domain impersonation to Quarantine the message**.
* Set **If Mailbox Intelligence detects an impersonated user to Quarantine the message**.
* Leave **Honor DMARC record policy when the message is detected as spoof** checked.
* Check **Show first contact safety tip (Recommended)**.
* Check **Show user impersonation safety tip**.
* Check **Show domain impersonation safety tip**.
* Check **Show user impersonation unusual characters safety tip**.
1. Finally click **Next** and **Submit** the policy.

>Note: DefaultFullAccessWithNotificationPolicy is suggested but not required. Users will be notified that impersonation emails are in the Quarantine

##### PowerShell

1. Connect to Exchange Online service using `Connect-ExchangeOnline`.
2. Run the following Exchange Online PowerShell script to create an AntiPhish policy:
```powershell
# Create the Policy
$params = @{
    Name                                = "CIS AntiPhish Policy"
    PhishThresholdLevel                 = 3
    EnableTargetedUserProtection        = $true
    EnableOrganizationDomainsProtection = $true
    EnableMailboxIntelligence           = $true
    EnableMailboxIntelligenceProtection = $true
    EnableSpoofIntelligence             = $true
    TargetedUserProtectionAction        = 'Quarantine'
    TargetedDomainProtectionAction      = 'Quarantine'
    MailboxIntelligenceProtectionAction = 'Quarantine'
    TargetedUserQuarantineTag           = 'DefaultFullAccessWithNotificationPolicy'
    MailboxIntelligenceQuarantineTag    = 'DefaultFullAccessWithNotificationPolicy'
    TargetedDomainQuarantineTag         = 'DefaultFullAccessWithNotificationPolicy'
    EnableFirstContactSafetyTips        = $true
    EnableSimilarUsersSafetyTips        = $true
    EnableSimilarDomainsSafetyTips      = $true
    EnableUnusualCharactersSafetyTips   = $true
    HonorDmarcPolicy                    = $true
}
New-AntiPhishPolicy @params
# Create the rule for all users in all valid domains and associate with Policy
New-AntiPhishRule -Name $params.Name -AntiPhishPolicy $params.Name -RecipientDomainIs (Get-AcceptedDomain).Name -Priority 0
```
3. The new policy can be edited in the UI or via PowerShell.

>Note: Remediation guidance is intended to help create a qualifying AntiPhish policy that meets the recommended criteria while protecting the majority of the organization. It's understood some individual user exceptions may exist or exceptions for the entire policy if another product acts as a similar control.


#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [Anti-phishing protection in cloud organizations](https://learn.microsoft.com/en-us/defender-office-365/anti-phishing-protection-about)
* [Configure anti-phishing policies for all cloud mailboxes](https://learn.microsoft.com/en-us/defender-office-365/anti-phishing-policies-eop-configure)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 94](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%