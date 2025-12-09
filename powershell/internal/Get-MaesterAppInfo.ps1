<#
.SYNOPSIS
    Returns a formatted object with information about a Maester application created in Entra.
#>
function Get-MaesterAppInfo {
    param (
        [Parameter(Mandatory = $true)]
        [object] $App
    )

    if($__MtSession.AdminPortalUrl){
        $adminBaseUrl = $__MtSession.AdminPortalUrl
    }
    else{
        $adminBaseUrl = 'https://entra.microsoft.com/'
    }
    $portalLink = "$($adminBaseUrl)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($app.appId)"

    # Create the output object
    $appInfo = [PSCustomObject]@{
        DisplayName     = $app.displayName
        AppId           = $app.appId
        Id        = $app.id
        PortalLink      = $portalLink
        Description     = $app.description
        CreatedDateTime = $app.createdDateTime
        Tags            = $app.tags
    }

    return $appInfo
}