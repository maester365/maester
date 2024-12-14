BeforeDiscovery {
    $ExchangeTransportRule = Get-TransportRule
    Write-Verbose "Found $($ExchangeTransportRule.Count) Exchange Transport rules"
    $OrganizationConfig = Get-OrganizationConfig
    Write-Verbose "Found Exchange Organization Config: $([bool]$OrganizationConfig)"
    $OwaMailboxPolicy = Get-OwaMailboxPolicy
    Write-Verbose "Found $($OwaMailboxPolicy.Count) Exchange Web mailbox policies"
    $OwaMailboxPolicyDefault =  $OwaMailboxPolicy | Where-Object {$_.Identity -eq "OwaMailboxPolicy-Default"}
    Write-Verbose "Filtered $($OwaMailboxPolicyDefault.Count) Default Web mailbox policy"
    $RoleAssignmentPolicy = Get-RoleAssignmentPolicy
    Write-Verbose "Found $($RoleAssignmentPolicy.Count) Exchange Role Assignment Policy"
    $RoleAssignmentPolicyDefault =  $RoleAssignmentPolicy | Where-Object {$_.Identity -eq "Default Role Assignment Policy"}
    Write-Verbose "Filtered $($RoleAssignmentPolicyDefault.Count) Default Web mailbox policy"
}

Describe "Exchange Setting" -Tag "Maester", "Exchange", "SecureScore" {
    $portalLink_SecureScore = "https://security.microsoft.com/securescore"

    It "MT.1037: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains" -Tag "SetScl", "TransportRule" {

        $portalLink_TransportRules = "https://admin.exchange.microsoft.com/#/transportrules"

        $RuleWithSCL = $ExchangeTransportRule | Where-Object { $_.SetScl -match "-1"}
        $result = ($RuleWithSCL).Count -gt 0

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. SetScl is not in use`n`n"
        } else {
            $testResultMarkdown = "SetScl is used $(($RuleWithSCL).Count) times in [Rules]($portalLink_TransportRules)`n`n"
        }
        $testDetailsMarkdown = "You should set Spam confidence level (SCL) in your Exchange Online mail transport rules with specific domains. Allow-listing domains in transport rules bypasses regular malware and phishing scanning, which can enable an attacker to launch attacks against your users from a safe haven domain. Note: In order to get a score for this security control, all the active transport rule that applies to specific domains must have a Spam Confidence Level (SCL) of 0 or higher."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        # Actual test
        if ($null -ne $result) {
            $result | Should -Be $false -Because "SetScl should be 0 (False)"
        }
    }

    It "MT.1038: Ensure modern authentication for Exchange Online is enabled" -Tag "OAuth2ClientProfileEnabled" {

        $result = $OrganizationConfig.OAuth2ClientProfileEnabled

        if ($result -eq $true) {
            $testResultMarkdown = "Well done. OAuth2ClientProfileEnabled is $($result)`n`n"
        } else {
            $testResultMarkdown = "OAuth2ClientProfileEnabled should be True and is $($result) in [SecureScore]($portalLink_SecureScore)`n`n"
        }
        $testDetailsMarkdown = "Modern authentication in Microsoft 365 enables authentication features like multifactor authentication (MFA) using smart cards, certificate-based authentication (CBA), and third-party SAML identity providers. When you enable modern authentication in Exchange Online, Outlook 2016 and Outlook 2013 use modern authentication to log in to Microsoft 365 mailboxes. When you disable modern authentication in Exchange Online, Outlook 2016 and Outlook 2013 use basic authentication to log in to Microsoft 365 mailboxes. When users initially configure certain email clients, like Outlook 2013 and Outlook 2016, they may be required to authenticate using enhanced authentication mechanisms, such as multifactor authentication. Other Outlook clients that are available in Microsoft 365 (for example, Outlook Mobile and Outlook for Mac 2016) always use modern uthentication to log in to Microsoft 365 mailboxes"
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        # Actual test
        if ($null -ne $result) {
            $result | Should -Be $true -Because "OAuth2ClientProfileEnabled should be True"
        }
    }

    It "MT.1039: Ensure MailTips are enabled for end users" -Tag "MailTipsExternalRecipientsTipsEnabled" {
        #Get-OrganizationConfig | fl MailTipsAllTipsEnabled, MailTipsExternalRecipientsTipsEnabled
        #Set-OrganizationConfig -MailTipsAllTipsEnabled $true -MailTipsExternalRecipientsTipsEnabled $true -MailTipsGroupMetricsEnabled $true -MailTipsLargeAudienceThreshold '25'

        $result = $OrganizationConfig.MailTipsExternalRecipientsTipsEnabled

        if ($result -eq $true) {
            $testResultMarkdown = "Well done. MailTipsExternalRecipientsTipsEnabled is $($result)`n`n"
        } else {
            $testResultMarkdown = "MailTipsExternalRecipientsTipsEnabled should be True and is $($result) in [SecureScore]($portalLink_SecureScore)`n`n"
        }
        $testDetailsMarkdown = "MailTips assist end users with identifying strange patterns to emails they send."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        # Actual test
        if ($null -ne $result) {
            $result | Should -Be $true -Because "MailTipsExternalRecipientsTipsEnabled should be True"
        }
    }

    # Y
    It "MT.1040: Ensure additional storage providers are restricted in Outlook on the web" -Tag "AdditionalStorageProvidersAvailable" {
        #Get-OwaMailboxPolicy | fl Name, AdditionalStorageProvidersAvailable, ThirdPartyFileProvidersEnabled, ConditionalAccessPolicy, ChangePasswordEnabled, *Offline*, ReportJunkEmailEnabled
        #Set-OwaMailboxPolicy -Identity OwaMailboxPolicy-Default -AdditionalStorageProvidersAvailable $false

        $result = $OwaMailboxPolicyDefault.AdditionalStorageProvidersAvailable

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AdditionalStorageProvidersAvailable is $($result)`n`n"
        } else {
            $testResultMarkdown = "AdditionalStorageProvidersAvailable should be False and is $($result) in [SecureScore]($portalLink_SecureScore)`n`n"
        }
        $testDetailsMarkdown = "This setting allows users to open certain external files while working in Outlook on the web. If allowed, keep in mind that Microsoft doesn't control the use terms or privacy policies of those third-party services. Ensure AdditionalStorageProvidersAvailable is restricted."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        # Actual test
        if ($null -ne $result) {
            $result | Should -Be $false -Because "AdditionalStorageProvidersAvailable should be False"
        }
    }

    # Z
    It "MT.1041: Ensure users installing Outlook add-ins is not allowed" -Tag "MyCustomApps", "MyMarketplaceApps", "MyReadWriteMailboxApps" {
        #Get-ManagementRoleAssignment -Role "My Custom Apps" -RoleAssignee $defaultrole | ft -AutoSize
        #Get-ManagementRoleAssignment -Role "My Marketplace Apps" -RoleAssignee $defaultrole | ft -AutoSize
        #Get-ManagementRoleAssignment -Role "My ReadWriteMailbox Apps" -RoleAssignee $defaultrole | ft -AutoSize

        $result = [bool](Get-ManagementRoleAssignment -Role "My Custom Apps" -RoleAssignee $RoleAssignmentPolicyDefault) -or  `
        [bool](Get-ManagementRoleAssignment -Role "My Marketplace Apps" -RoleAssignee $RoleAssignmentPolicyDefault) -or  `
        [bool](Get-ManagementRoleAssignment -Role "My ReadWriteMailbox Apps" -RoleAssignee $RoleAssignmentPolicyDefault)

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. Apps in 'Default Role Assignment Policy' is $($result)`n`n"
        } else {
            $testResultMarkdown = "Apps in 'Default Role Assignment Policy' should be False and is $($result) in [SecureScore]($portalLink_SecureScore)`n`n"
        }
        $testDetailsMarkdown = "Specify the administrators and users who can install and manage add-ins for Outlook in Exchange Online By default, users can install add-ins in their Microsoft Outlook Desktop client, allowing data access within the client application. Rationale: Attackers exploit vulnerable or custom add-ins to access user data. Disabling user installed add-ins in Microsoft Outlook reduces this threat surface."
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        # Actual test
        if ($null -ne $result) {
            $result | Should -Be $false -Because "Apps in 'Default Role Assignment Policy' should be False"
        }
    }
}
