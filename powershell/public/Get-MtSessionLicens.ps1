function Get-MtSessionLicens {
    <#
    .SYNOPSIS
        Returns the pre-fetched license map for the current tenant session.

    .DESCRIPTION
        Returns a hashtable of all license products evaluated for the current tenant.
        The map is populated once by Initialize-MtSession (called at the start of Invoke-Maester)
        so that BeforeDiscovery blocks in test files can gate tests on license availability
        without making additional Graph API calls.

        Keys match the -Product parameter of Get-MtLicenseInformation.
        Use this function in BeforeDiscovery blocks instead of calling Get-MtLicenseInformation
        per-product.

    .EXAMPLE
        BeforeDiscovery {
            $Licenses = Get-MtSessionLicens
        }

        Describe "Maester/Entra" -Tag "Maester", "Entra" {
            It "MT.XXXX: ..." -Tag "MT.XXXX" -Skip:($Licenses.EntraID -eq "Free") {
                Test-MtSomeP1Feature | Should -Be $true
            }
            It "MT.XXXY: ..." -Tag "MT.XXXY" -Skip:($Licenses.EntraID -ne "P2") {
                Test-MtSomeP2Feature | Should -Be $true
            }
            It "MT.XXXZ: ..." -Tag "MT.XXXZ" -Skip:($null -eq $Licenses.Intune) {
                Test-MtSomeIntuneFeature | Should -Be $true
            }
        }

    .LINK
        https://maester.dev/docs/commands/Get-MtSessionLicens
    #>
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    Write-Verbose "Returning session license cache with $($__MtSession.Licenses.Count) products."
    return $__MtSession.Licenses
}
