<#
 .Synopsis
    Returns the list of Graph scopes required to run Maester.

 .Description
    Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

 .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope)

    Connects to Microsoft Graph with the required scopes to run Maester.

 .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail)

    Connects to Microsoft Graph with the required scopes to run Maester and send email.

 .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -SendTeamsMessage)

    Connects to Microsoft Graph with the required scopes to run Maester and send messages to a Teams Channel.

 .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -PrivilegedScopes)

    Connects to Microsoft Graph with the required scopes to run Maester for all tests, including those requiring read write APIs.

.LINK
    https://maester.dev/docs/commands/Get-MtGraphScope
#>
function Get-MtGraphScope {

    [CmdletBinding()]
    param(
        # If specified, the cmdlet will include the scope to send email (Mail.Send).
        [Parameter(Mandatory = $false)]
        [switch] $SendMail,
        # If specified, the cmdlet will include the scope to send Teams Channel Messages (ChannelMessage.Send).
        [Parameter(Mandatory = $false)]
        [switch] $SendTeamsMessage,
        # If specified, the cmdlet will include the scope for read write endpoints.
        [Parameter(Mandatory = $false)]
        [switch] $Privileged
    )

    # Any changes made to these permission scopes should be reflected in the documentation.
    # /maester/website/docs/sections/permissions.md
    #
    # NOTE: We should only include read-only permissions in the default scopes.
    # Other permissions should be opted-in by the user with switches like -SendMail.


    # Default read-only scopes required for Maester.
    $scopes = @( #IMPORTANT: Read note above before adding any new scopes.
        'Directory.Read.All'
        'Policy.Read.All'
        'Reports.Read.All'
        'DirectoryRecommendations.Read.All'
        'PrivilegedAccess.Read.AzureAD'
        'IdentityRiskEvent.Read.All'
        'RoleEligibilitySchedule.Read.Directory'
        'RoleManagement.Read.All'
        'Policy.Read.ConditionalAccess'
        'SharePointTenantSettings.Read.All'
        'UserAuthenticationMethod.Read.All'
    )

    # Any changes made to these permission scopes should be reflected in the documentation.
    # /maester/website/docs/sections/privilegedPermissions.md
    $privilegedScopes = @(
        'RoleEligibilitySchedule.ReadWrite.Directory' #Ref https://github.com/maester365/maester/issues/195#issuecomment-2170879665
    )

    if ($Privileged) {
        Write-Verbose -Message "Adding Privileged scopes."
        $privilegedScopes | ForEach-Object { `
            $scopes += $_
        }
    }

    if ($SendMail) {
        Write-Verbose -Message "Adding SendMail scope."
        $scopes += 'Mail.Send'
    }

    if ($SendTeamsMessage) {
        Write-Verbose -Message "Adding SendTeamsMessage scope."
        $scopes += 'ChannelMessage.Send'
    }

    return $scopes
}