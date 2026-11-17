BeforeAll {
    $testPath = Join-Path $PSScriptRoot '../../../../tests/ad/config/Test.AD-CFG-08.ps1'
    $source = Get-Content -LiteralPath $testPath -Raw
    $functionStart = $source.IndexOf('function Test-MtAdAuthNPolicyConfigCount')
    $attributeStart = $source.IndexOf('[MaesterTest(', $functionStart)
    if ($functionStart -lt 0 -or $attributeStart -lt 0) {
        throw 'Unable to locate Test-MtAdAuthNPolicyConfigCount or its MaesterTest attribute.'
    }
    $attributeEnd = $source.IndexOf(')]', $attributeStart)
    if ($attributeEnd -lt 0) {
        throw 'Unable to locate the end of the MaesterTest attribute.'
    }
    $testableSource = $source.Remove($attributeStart, ($attributeEnd + 2) - $attributeStart)

    # Declare test-scope dependency stubs before loading the function under test. This prevents
    # an installed Maester version from contributing stale ValidateSet metadata to Pester mocks.
    function Get-MtADDomainState {
        param([string[]] $Categories)
        throw 'Get-MtADDomainState must be mocked by each behavioral test.'
    }
    function Add-MtTestResultDetail {
        param($SkippedBecause, $SkippedCustomReason, $Result)
    }
    function Get-MtSafeMarkdown {
        param([string] $Text)
        return $Text
    }

    . ([scriptblock]::Create($testableSource))
}
Describe 'AD-CFG-08 evidence disposition' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        Mock Get-MtSafeMarkdown { param($Text) $Text }
    }
    It 'uses NotConnectedActiveDirectory when domain state is unavailable' {
        Mock Get-MtADDomainState { $null }
        Test-MtAdAuthNPolicyConfigCount | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotConnectedActiveDirectory' }
    }
    It 'uses a custom collection-failure reason when the category state is unavailable' {
        Mock Get-MtADDomainState { [ordered]@{ AuthenticationPolicyState=$null } }
        Test-MtAdAuthNPolicyConfigCount | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'LDAP evidence is unavailable' }
    }
    It 'returns true for a valid empty state without a skip' {
        Mock Get-MtADDomainState { [ordered]@{ AuthenticationPolicyState=[PSCustomObject]@{PolicyCount=0;EnforcedPolicyCount=0;SiloCount=0;EnforcedSiloCount=0;NonEnforcedSilos=@()} } }
        Test-MtAdAuthNPolicyConfigCount | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $null -ne $Result }
        Should -Invoke Add-MtTestResultDetail -Times 0 -ParameterFilter { $null -ne $SkippedBecause }
    }
    It 'lists sanitized non-enforced silo names in a valid populated result' {
        Mock Get-MtADDomainState { [ordered]@{ AuthenticationPolicyState=[PSCustomObject]@{PolicyCount=1;EnforcedPolicyCount=1;SiloCount=1;EnforcedSiloCount=0;NonEnforcedSilos=@('Tier|0 Silo')} } }
        Mock Get-MtSafeMarkdown { param($Text) $Text.Replace('|','\|') }
        Test-MtAdAuthNPolicyConfigCount | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Tier\\\|0 Silo' }
    }
}
