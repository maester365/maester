<#

    .SYNOPSIS
    Get the deep link to the Microsoft Entra admin portal for a specific Graph object type.
#>

function Get-MtLinkServicePrincipal {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $ServicePrincipal,

        # The blade to use for the link, defaults to "Overview"
        [Parameter(Mandatory = $false)]
        [ValidateSet('Overview', 'Permissions')]
        [string] $Blade = 'Overview'
    )

    switch ($Blade) {
        'Overview' {
            $link = "[$($ServicePrincipal.DisplayName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($ServicePrincipal.id)/appId/$($ServicePrincipal.appId))"
        }
        'Permissions' {
            $link = "[$($ServicePrincipal.DisplayName)]($($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/$($ServicePrincipal.id)/appId/$($ServicePrincipal.appId))"
        }
    }
    return $link
}