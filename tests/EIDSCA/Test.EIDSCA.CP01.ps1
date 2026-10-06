function Test-MtCheckEidscaCP01 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Group owner consent for apps accessing data is 'False'

    .DESCRIPTION
    Group and team owners can authorize applications, such as applications published by third-party vendors, to access your organization's data associated with a group. For example, a team owner in Microsoft Teams can allow an app to read all Teams messages in the team, or list the basic profile of a group's members.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaCP01
    and passes when it -eq 'False'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CP01',
        Title = 'Default Settings - Consent Policy Settings - Group owner consent for apps accessing data.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $SettingsApiAvailable = (Invoke-MtGraphRequest -RelativeUri 'settings' -ApiVersion beta).values.name
    if ( $SettingsApiAvailable -notcontains 'EnableGroupSpecificConsent' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Group owner consent settings have been removed and replaced with Team owner consent settings.'
        return $null
    }

    $tenantValue = Test-MtEidscaCP01
    return ($tenantValue -eq 'False')
}
