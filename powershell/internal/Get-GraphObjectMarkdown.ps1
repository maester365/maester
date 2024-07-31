<#
 .Synopsis
    Creates a markdown of Graph results to be used in test results.

 .Description
    Generates a list of markdown items with support for deeplinks to the Entra portal for known Graph object types.

 .Example

    Get-GraphResultMarkdown -GraphObjects $policies -GraphObjectType ConditionalAccess

    Returns a markdown list of Conditional Access policies with deeplinks to the relevant CA blade in Entra portal.
#>

function Get-GraphObjectMarkdown {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Collection of Graph objects to display as markdown.
        [Parameter(Mandatory = $true)]
        [Object[]] $GraphObjects,

        # The type of graph object, this will be used to show the right deeplink to the test results report.
        [Parameter(Mandatory = $true)]
        [ValidateSet('AuthenticationMethod', 'AuthorizationPolicy', 'ConditionalAccess', 'ConsentPolicy',
            'Devices', 'Domains', 'Groups', 'IdentityProtection', 'Users', 'UserRole'
            )]
        [string] $GraphObjectType,

        [Parameter(Mandatory = $false)]
        [switch] $AsPlainTextLink
    )

    $markdownLinkTemplate = @{
        AuthenticationMethod = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods"
        AuthorizationPolicy  = "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings"
        ConditionalAccess    = "https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/{0}"
        ConsentPolicy        = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings"
        Devices              = "https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DeviceDetailsMenuBlade/~/Properties/objectId/{0}"
        Domains              = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomDomainNames"
        Groups               = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/{0}"
        IdentityProtection   = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/IdentityProtectionMenuBlade/~/UsersAtRiskAlerts/fromNav/Identity"
        Users                = "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/{0}"
        UserRole             = "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/AdministrativeRole/userId/{0}"
    }

    # This will work for now, will need to add switch as we add support for complex urls like Applications blade, etc..
    $result = ""
    foreach ($item in $GraphObjects) {
        $link = $markdownLinkTemplate[$GraphObjectType] -f $item.id
        if ($AsPlainTextLink) {
            $result += "[$($item.displayName)]($link)"
        } else {
            $result += "  - [$($item.displayName)]($link)`n"
        }
    }

    return $result
}