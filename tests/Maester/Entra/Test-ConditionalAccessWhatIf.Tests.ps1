BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
    $RegularUsers = Get-MtUser -Count 2 -UserType "Member"
    $AdminUsers = Get-MtUser -Count 1 -UserType "Admin"
    Write-Verbose "EntraIDPlan: $EntraIDPlan"
    Write-Verbose "RegularUsers: $($RegularUsers.id)"
    Write-Verbose "AdminUsers: $($AdminUsers.id)"
}


Describe "Conditional Access WhatIf" -Tag "CA", "CAWhatIf", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) -ForEach @( $RegularUsers ) {

    It "MT.1023: User should be blocked from using legacy authentication (<userPrincipalName>)" {
        Test-MtCaWIFBlockLegacyAuthentication -UserId $id | Should -Be $true
    }

}