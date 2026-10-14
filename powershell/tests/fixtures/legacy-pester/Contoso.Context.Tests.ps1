# Legacy Pester fixture: Context blocks inside a Describe, each with their own tags.
# 2.x drops the Describe tags from the result row of a test inside a Context.
Describe "Contoso Exchange" -Tag "Contoso", "EXO" {
    Context "Mail flow" -Tag "MailFlow" {
        It "CONTOSO.4001: External forwarding is disabled" -Tag "CONTOSO.4001" {
            $forwarding = 'Off'
            $forwarding | Should -Be 'Off'
        }
    }

    Context "Auditing" -Tag "Audit" {
        It "CONTOSO.4002: Mailbox auditing is on" -Tag "CONTOSO.4002" {
            $auditEnabled = $false
            $auditEnabled | Should -BeTrue
        }
    }
}
