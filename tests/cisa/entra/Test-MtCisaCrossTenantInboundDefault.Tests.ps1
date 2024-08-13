Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.8.3", "CISA", "Security", "All", "Entra ID Free" {
    It "MS.AAD.8.3: Guest invites SHOULD only be allowed to specific external domains that have been authorized by the agency for legitimate business purposes." {
        $result = Test-MtCisaCrossTenantInboundDefault

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default inbound cross-tenant access policy is set to block."
        }
    }
}