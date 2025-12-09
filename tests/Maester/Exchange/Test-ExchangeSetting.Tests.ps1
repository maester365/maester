Describe "Maester/Exchange" -Tag "Maester", "Exchange" {

    It "MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains" -Tag "MT.1043", "SetScl", "TransportRule", "SecureScore" {
        $result = Test-MtExoSetScl

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SetScl should not be set to -1"
        }
    }

    It "MT.1044: Ensure modern authentication for Exchange Online is enabled" -Tag "MT.1044", "OAuth2ClientProfileEnabled", "SecureScore" {
        $result = Test-MtExoModernAuth

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OAuth2ClientProfileEnabled should be True"
        }
    }

    It "MT.1039: Ensure MailTips are enabled for end users" -Tag "MT.1039", "MailTipsExternalRecipientsTipsEnabled", "SecureScore" {
        $result = Test-MtExoMailTip

        if ($null -ne $result) {
            $result | Should -Be $true -Because "MailTipsExternalRecipientsTipsEnabled should be True"
        }
    }

    It "MT.1040: Ensure additional storage providers are restricted in Outlook on the web" -Tag "MT.1040", "AdditionalStorageProvidersAvailable", "SecureScore" {
        $result = Test-MtExoAdditionalStorageProvider

        if ($null -ne $result) {
            $result | Should -Be $true -Because "AdditionalStorageProvidersAvailable should be False"
        }
    }

    It "MT.1041: Ensure users installing Outlook add-ins is not allowed" -Tag "MT.1041", "MyCustomApps", "MyMarketplaceApps", "MyReadWriteMailboxApps", "SecureScore" {
        $result = Test-MtExoOutlookAddin

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Apps in 'Default Role Assignment Policy' should be False"
        }
    }

    It "MT.1062: Ensure Direct Send is set to be rejected" -Tag "MT.1062", "RejectDirectSend" {

        $result = Test-MtExoRejectDirectSend

        if ($result -ne $true) {
            $result | Should -Be $true -Because "RejectDirectSend should be True."
        }
    }

    It "MT.1074: Ensure no more then 100 outbound mails per day are send using the .onmicrosoft.com domain" -Tag "MT.1074" {

        $result = Test-MtLimitOnMicrosoftDomainUsage

        if ($null -ne $result) {
            $result | Should -Be $true -Because "no or less then 100 outbound mails are send per day using the .onmicrosoft.com domain."
        }
    }

    It "MT.1076: MOERA SHOULD NOT be used for sent mail" -Tag "MT.1076", "MOERA" {

        $result = Test-MtExoMoeraMailActivity

        if ($result -ne $true) {
            $result | Should -Be $true -Because "MOERA is not in use."
        }
    }

    It "MT.1083: Ensure Delicensing Resiliency is enabled" -Tag "MT.1083", "DelicensingResiliency" {

        $result = Test-MtExoDelicensingResiliency

        if ($result -ne $true) {
            $result | Should -Be $true -Because "Delicensing Resiliency should be enabled."
        }
    }

    # Ensure 'External sharing' of calendars is not available:
    # > CIS 1.3.3 (L2) Ensure 'External sharing' of calendars is not available
    # > MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains.

    # Ensure the customer lockbox feature is enabled:
    # > CIS 1.3.6 (L2) Ensure the customer lockbox feature is enabled

    # Ensure mailbox auditing for all users is Enabled:
    # > MS.EXO.13.1: Mailbox auditing SHALL be enabled.
}
