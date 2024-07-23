BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
    $RegularUsers = Get-MtUser -Count 5 -UserType "Member"
    $AdminUsers = Get-MtUser -Count 5 -UserType "Admin"
    $EmergencyAccessUsers = Get-MtUser -Count 5 -UserType "EmergencyAccess"
    # Remove emergency access users from regular users
    $RegularUsers = $RegularUsers | Where-Object { $_.id -notin $EmergencyAccessUsers.id }
    # Remove emergency access users from admin users
    $AdminUsers = $AdminUsers | Where-Object { $_.id -notin $EmergencyAccessUsers.id }
    Write-Verbose "EntraIDPlan: $EntraIDPlan"
    Write-Verbose "RegularUsers: $($RegularUsers.id)"
    Write-Verbose "AdminUsers: $($AdminUsers.id)"
}


Describe "Conditional Access WhatIf" -Tag "Maester", "CA", "CAWhatIf", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {

    Context "Regular users" -ForEach @( $RegularUsers ) {

        It "MT.1033: User should be blocked from using legacy authentication (<userPrincipalName>)" -Tag "MT.1033" {
            Test-MtCaWIFBlockLegacyAuthentication -UserId $id | Should -Be $true
        }

    }

    Context "Emergency access users" -ForEach @( $EmergencyAccessUsers ) {

        It "MT.1034: Emergency access users should not be blocked (<userPrincipalName>)" -Tag "MT.1034" {
            if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
                Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
            } else {
                Test-MtConditionalAccessWhatIf -UserId $id -IncludeApplications "00000002-0000-0ff1-ce00-000000000000" -ClientAppType exchangeActiveSync | Should -BeNullOrEmpty
            }
        }

    }

}