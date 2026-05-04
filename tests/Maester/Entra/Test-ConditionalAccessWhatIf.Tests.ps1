BeforeDiscovery {
    try {
        $Licenses = Get-MtSessionLicense
        $EntraIDPlan = $Licenses.EntraID
        $RegularUsers = Get-MtUser -Count 5 -UserType 'Member'
        $AdminUsers = Get-MtUser -Count 5 -UserType 'Admin'
        $EmergencyAccessUsers = Get-MtUser -Count 5 -UserType 'EmergencyAccess'
        # Remove emergency access users from regular users
        $RegularUsers = $RegularUsers | Where-Object { $_.id -notin $EmergencyAccessUsers.id }
        # Remove emergency access users from admin users
        $AdminUsers = $AdminUsers | Where-Object { $_.id -notin $EmergencyAccessUsers.id }
        Write-Verbose "EntraIDPlan: $EntraIDPlan"
        Write-Verbose "RegularUsers: $($RegularUsers.id)"
        Write-Verbose "AdminUsers: $($AdminUsers.id)"
    } catch {
        $EntraIDPlan = "NotConnected"
    }
}


Describe 'Maester/Entra' -Tag 'CA', 'CAWhatIf', 'LongRunning', 'Maester' {

    Context 'Maester/Entra' -ForEach @( $RegularUsers ) {
        # Regular users
        It "MT.1033.$([array]::IndexOf(@($RegularUsers), $_)): User should be blocked from using legacy authentication ($($_.userPrincipalName))" -Tag 'MT.1033', 'CA', 'CAWhatIf', 'LongRunning', 'Maester' -Skip:( $EntraIDPlan -eq 'Free' ) {
            Test-MtCaWIFBlockLegacyAuthentication -UserId $id | Should -Be $true
        }

    }

    Context 'Maester/Entra' -ForEach @( $EmergencyAccessUsers ) {
        # Emergency access users
        It "MT.1034.$([array]::IndexOf(@($EmergencyAccessUsers), $_)): Emergency access users should not be blocked ($($_.userPrincipalName))" -Tag 'MT.1034' -Skip:($EntraIDPlan -eq 'Free') {
            Test-MtConditionalAccessWhatIf -UserId $id -IncludeApplications '00000002-0000-0ff1-ce00-000000000000' -ClientAppType exchangeActiveSync | Should -BeNullOrEmpty
        }

    }

}
