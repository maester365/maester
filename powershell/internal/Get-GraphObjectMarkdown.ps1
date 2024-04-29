<#
 .Synopsis
    Creates a markdown of Graph results to be used in test results.

 .Description
    Generates a list of markdown items with support for deeplinks to the Entra portal for known Graph object types.

 .Example

    Get-GraphResultMarkdown -GraphObjects $policies -GraphObjectType ConditionalAccess

    Returns a markdown list of Conditional Access policies with deeplinks to the relevant CA blade in Entra portal.
#>

Function Get-GraphObjectMarkdown {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Collection of Graph objects to display as markdown.
        [Parameter(Mandatory = $true)]
        [Object[]] $GraphObjects,

        # The type of graph object, this will be used to show the right deeplink to the test results report.
        [Parameter(Mandatory = $true)]
        [ValidateSet('ConditionalAccess', 'User', 'Group', 'Device', 'IdentityProtection', 'AuthenticationMethod')]
        [string] $GraphObjectType
    )

    $markdownLinkTemplate = @{
        ConditionalAccess    = "https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/{0}"
        User                 = "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/{0}"
        Group                = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/{0}"
        Device               = "https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DeviceDetailsMenuBlade/~/Properties/objectId/{0}"
        IdentityProtection   = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/IdentityProtectionMenuBlade/~/UsersAtRiskAlerts/fromNav/Identity"
        AuthenticationMethod = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods"
    }

    # This will work for now, will need to add switch as we add support for complex urls like Applications blade, etc..
    $result = ""
    foreach ($item in $GraphObjects) {
        $link = $markdownLinkTemplate[$GraphObjectType] -f $item.id
        $result += "  - [$($item.displayName)]($link)`n"
    }

    return $result
}