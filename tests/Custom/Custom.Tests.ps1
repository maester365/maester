Describe "ContosoConfig" -Tag "Privilege" {
    It "Check approved Global Admins" {

        # Approved list of Global Admins
        $approvedGlobalAdmins = @("john@contoso.com", "emergency@contoso.com")

        # Get all Global Admins
        $roleId = (Get-MgDirectoryRole -Filter "DisplayName eq 'Global Administrator'").Id
        $globalAdmins = Get-MgDirectoryRoleMember -DirectoryRoleId $roleId
        $globalAdmins = $globalAdmins.AdditionalProperties.userPrincipalName

        # Check if the Global Admins are approved
        $globalAdmins | Should -BeIn $approvedGlobalAdmins
    }
}









