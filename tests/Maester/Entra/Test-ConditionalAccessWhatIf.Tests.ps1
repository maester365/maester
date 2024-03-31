BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
    $RegularUsers = Get-MtUser -Count 1
    $AdminUsers = Get-MtUser -Count 1 -UserType "Admin"
    Write-Verbose "EntraIDPlan: $EntraIDPlan"
    Write-Verbose "RegularUsers: $($RegularUsers.id)"
    Write-Verbose "AdminUsers: $($AdminUsers.id)"
}


Describe "Conditional Access WhatIf" -Tag "CA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {

    It "User should be blocked from using legacy authentication" -ForEach @( $RegularUsers ) {
        $Result = Test-MtCaWIFBlockLegacyAuthentication -UserId $_.id
        $Result | Should -Be $true
    }

}