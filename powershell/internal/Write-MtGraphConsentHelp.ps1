function Write-MtGraphConsentHelp {
    <#
    .SYNOPSIS
    Prints guidance when Connect-MgGraph fails because the signed-in user cannot consent to the Maester scopes.

    .DESCRIPTION
    Non-admin accounts such as Global Reader cannot consent to the Microsoft Graph scopes that Maester requests.
    When the admin consent workflow is enabled, the user sees an 'Approval required' prompt and
    Connect-MgGraph fails with 'User canceled authentication'. Approving that request from the
    Entra admin center can fail with 'AADSTS70011 ... openid scope is required', so this helper
    points the user at admin consent from PowerShell or a custom app registration instead.

    Returns $true if guidance was printed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    param(
        # The errors written by Connect-MgGraph.
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [System.Management.Automation.ErrorRecord[]] $ErrorRecord,

        # The custom client ID passed to Connect-Maester, if any.
        [string] $GraphClientId,

        [switch] $SendMail,

        [switch] $SendTeamsMessage,

        [switch] $Privileged,

        [switch] $IncludePreview
    )

    # AADSTS65001: consent not granted. AADSTS90094/AADSTS90095: admin approval required.
    # 'User canceled authentication' is what Connect-MgGraph reports after an 'Approval required' prompt.
    $consentErrorPattern = 'AADSTS65001|AADSTS90094|AADSTS90095|User canceled authentication'

    $consentError = $ErrorRecord | Where-Object { $_ -and "$($_.Exception.Message) $($_.ErrorDetails.Message)" -match $consentErrorPattern }
    if (-not $consentError) {
        return $false
    }

    $scopeSwitches = @(
        if ($SendMail) { '-SendMail' }
        if ($SendTeamsMessage) { '-SendTeamsMessage' }
        if ($Privileged) { '-Privileged' }
        if ($IncludePreview) { '-IncludePreview' }
    ) -join ' '
    $scopeCommand = "(Get-MtGraphScope $scopeSwitches)".Replace(' )', ')')
    $consentCommand = "Connect-MgGraph -Scopes $scopeCommand"
    if ($GraphClientId) {
        $consentCommand += " -ClientId '$GraphClientId'"
    }

    Write-Host ''
    Write-Host '⚠️  Microsoft Graph sign-in did not complete.' -ForegroundColor Yellow
    Write-Host "If you saw an 'Approval required' or 'Need admin approval' prompt, your account cannot consent to the" -ForegroundColor Yellow
    Write-Host 'Microsoft Graph permissions Maester needs. This is expected for Global Reader and other non-admin accounts.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Ask a Global Administrator or Privileged Role Administrator to do one of the following:' -ForegroundColor White
    Write-Host ''
    Write-Host " 1. Grant consent for the organization (recommended)" -ForegroundColor Cyan
    Write-Host "    Run this command, sign in as the admin, and select 'Consent on behalf of your organization' before Accept:" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "      $consentCommand" -ForegroundColor Green
    Write-Host ''
    Write-Host '    Then run Connect-Maester again with your own account.' -ForegroundColor Cyan
    Write-Host "    Note: Approving the request from 'Admin consent requests' in the Entra admin center can fail with" -ForegroundColor DarkGray
    Write-Host "    'AADSTS70011 ... openid scope is required'. Use the command above instead." -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ' 2. Use a custom app registration' -ForegroundColor Cyan
    Write-Host '    Create an app registration with the Maester delegated permissions, grant admin consent, then run:' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "      Connect-Maester -GraphClientId '<application-client-id>'" -ForegroundColor Green
    Write-Host ''
    Write-Host '    See https://learn.microsoft.com/powershell/microsoftgraph/authentication-commands#use-delegated-access-with-a-custom-application-for-microsoft-graph-powershell' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'More info: https://maester.dev/docs/connect-maester/#approval-required-when-connecting' -ForegroundColor Yellow
    Write-Host ''

    return $true
}
