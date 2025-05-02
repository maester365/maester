param (
    [Parameter(Mandatory = $true, HelpMessage = 'The Entra Tenant Id')]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = 'The Client Id of the Service Principal')]
    [string]$ClientId,

    [Parameter(Mandatory = $true, HelpMessage = 'The path for the files and pester tests')]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = 'The Pester verbosity level')]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$PesterVerbosity = 'None',

    [Parameter(Mandatory = $false, HelpMessage = 'The mail user id')]
    [string]$MailUser = '',

    [Parameter(Mandatory = $false, HelpMessage = 'The mail recipients separated by comma')]
    [string]$MailRecipients = '',

    [Parameter(Mandatory = $false, HelpMessage = 'The test result uri')]
    [string]$TestResultURI = '',

    [Parameter(Mandatory = $false, HelpMessage = 'The tags to include in the tests')]
    [string]$IncludeTags = '',

    [Parameter(Mandatory = $false, HelpMessage = 'The tags to exclude in the tests')]
    [string]$ExcludeTags = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Include Exchange Online tests')]
    [bool]$IncludeExchange = $true,

    [Parameter(Mandatory = $false, HelpMessage = 'Include Teams tests')]
    [bool]$IncludeTeams = $true,

    [Parameter(Mandatory = $false, HelpMessage = 'Install preview version of Maester')]
    [bool]$Preview = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'Disable telemetry')]
    [bool]$DisableTelemetry = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'Add test results to GitHub step summary')]
    [bool]$GitHubStepSummary = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'Teams Webhook Uri to send test results to, see: https://maester.dev/docs/monitoring/teams')]
    [string]$TeamsWebhookUri = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'Teams notification channel ID')]
    [string]$TeamsChannelId = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'Teams notification team ID')]
    [string]$TeamsTeamId = $null
)

BEGIN {
    Write-Host 'Starting Maester tests'
}
PROCESS {
    $graphToken = Get-MtAccessTokenUsingCli -ResourceUrl 'https://graph.microsoft.com' -AsSecureString

    # Connect to Microsoft Graph with the token as secure string
    Connect-MgGraph -AccessToken $graphToken -NoWelcome

    # Check if we need to connect to Exchange Online
    if ($IncludeExchange) {
        Install-Module ExchangeOnlineManagement -Force
        Import-Module ExchangeOnlineManagement

        $outlookToken = Get-MtAccessTokenUsingCli -ResourceUrl 'https://outlook.office365.com'
        Connect-ExchangeOnline -AccessToken $outlookToken -AppId $ClientId -Organization $TenantId -ShowBanner:$false
    } else {
        Write-Host 'Exchange Online tests will be skipped.'
    }

    # Check if we need to connect to Teams
    if ($IncludeTeams) {
        Install-Module MicrosoftTeams -Force
        Import-Module MicrosoftTeams

        $teamsToken = Get-MtAccessTokenUsingCli -ResourceUrl '48ac35b8-9aa8-4d74-927d-1f4a14a0b239'

        $regularGraphToken = ConvertFrom-SecureString -SecureString $graphToken -AsPlainText
        $tokens = @($regularGraphToken, $teamsToken)
        Connect-MicrosoftTeams -AccessTokens $tokens -Verbose
    } else {
        Write-Host 'Teams tests will be skipped.'
    }

    # Install Maester
    if ($Preview) {
        Install-Module Maester -AllowPrerelease -Force
    } else {
        Install-Module Maester -Force
    }


    # Delete Microsoft.Graph.Authentication 2.9.1 (tmp fix for issue #606)
    Write-Host 'Delete module version 2.9.1 of Microsoft.Graph.Authentication'
    rm -r /home/runner/.local/share/powershell/Modules/Microsoft.Graph.Authentication/2.9.1

    # Configure test results
    $PesterConfiguration = New-PesterConfiguration
    $PesterConfiguration.Output.Verbosity = $PesterVerbosity
    Write-Host "Pester verbosity level set to: $($PesterConfiguration.Output.Verbosity.Value)"

    $MaesterParameters = @{
        Path                 = $Path
        PesterConfiguration  = $PesterConfiguration
        OutputFolder         = 'test-results'
        OutputFolderFileName = 'test-results'
        PassThru             = $true
    }

    # Check if test tags are provided
    if ( [string]::IsNullOrWhiteSpace($IncludeTags) -eq $false ) {
        $TestTags = $IncludeTags -split ','
        $MaesterParameters.Add( 'Tag', $TestTags )
        Write-Host "Running tests with tags: $TestTags"
    }

    # Check if exclude test tags are provided
    if ( [string]::IsNullOrWhiteSpace($ExcludeTags) -eq $false ) {
        $ExcludeTestTags = $ExcludeTags -split ','
        $MaesterParameters.Add( 'ExcludeTag', $ExcludeTestTags )
        Write-Host "Excluding tests with tags: $ExcludeTestTags"
    }

    # Check if mail recipients and mail userid are provided
    if ( [string]::IsNullOrWhiteSpace($MailUser) -eq $false ) {
        if ( [string]::IsNullOrWhiteSpace( '${{ inputs.mail_recipients }}' ) -eq $false ) {
            # Add mail parameters
            $MaesterParameters.Add( 'MailUserId', $MailUser )
            $Recipients = $MailRecipients -split ','
            $MaesterParameters.Add( 'MailRecipient', $Recipients )
            $MaesterParameters.Add( 'MailTestResultsUri', $TestResultURI )
            Write-Host "Mail notification will be sent to: $Recipients"
        } else {
            Write-Warning 'Mail recipients are not provided. Skipping mail notification.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($TeamsChannelId) -eq $false -and [string]::IsNullOrWhiteSpace($TeamsTeamId) -eq $false) {
        $MaesterParameters.Add( 'TeamChannelId', $TeamsChannelId )
        $MaesterParameters.Add( 'TeamId', $TeamsTeamId )
        Write-Host "Results will be sent to Teams Team Id: $TeamsTeamId"
    }

    # Check if disable telemetry is provided
    if ($DisableTelemetry ) {
        $MaesterParameters.Add( 'DisableTelemetry', $true )
    }

    # Check if Teams Webhook Uri is provided
    if ($TeamsWebhookUri) {
        $MaesterParameters.Add( 'TeamChannelWebhookUri', $TeamsWebhookUri )
        Write-Host "::add-mask::$TeamsWebhookUri"
        Write-Host "Sending test results to Teams Webhook Uri: $TeamsWebhookUri"
    }

    # Run Maester tests
    $results = Invoke-Maester @MaesterParameters

    if ($GitHubStepSummary) {
        Write-Host "Adding test results to GitHub step summary"
        # Add step summary
        $filePath = "test-results/test-results.md"
        if (Test-Path $filePath) {
            $maxSize = 1024KB
            $truncationMsg = "`n`n**⚠ TRUNCATED: Output exceeded GitHub's 1024 KB limit.**"

            # Check file size
            $fileSize = (Get-Item $filePath).Length
            if ($fileSize -gt $maxSize) {
                Write-Host "File size exceeds 1MB. Truncating the file."

                # Read the file content
                $content = Get-Content $filePath -Raw

                # Calculate the maximum content size to fit within the limit
                $maxContentSize = $maxSize - ($truncationMsg.Length * [System.Text.Encoding]::UTF8.GetByteCount("a")) - 4KB

                # Truncate the content
                $truncatedContent = $content.Substring(0, $maxContentSize / [System.Text.Encoding]::UTF8.GetByteCount("a"))

                # Write the truncated content and truncation message to the new file
                $truncatedContent | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding UTF8 -Append
                Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $truncationMsg

            } else {
                Write-Host "File size is within the limit. No truncation needed."
                Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $(Get-Content $filePath)
            }
        } else {
            Write-Host "File not found: $filePath"
        }
    }

    # Write output variable
    $testResultsFile = "test-results/test-results.json"
    $fullTestResultsFile = Resolve-Path -Path $testResultsFile -ErrorAction SilentlyContinue
    Write-Host "Test results file: $fullTestResultsFile"
    if (Test-Path $fullTestResultsFile) {
        try {
            Write-Host "Writing test result location to output variable"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "results_json=$fullTestResultsFile"
        } catch {
            Write-Host "Failed to write test result location to output variable. $($_.Exception.Message) at $($_.InvocationInfo.Line) in $($_.InvocationInfo.ScriptName)"
            Write-Host "::error file=$($_.InvocationInfo.ScriptName),line=$($_.InvocationInfo.Line),title=Maester exception::Failed to write test result location to output variable."
        }
    }


}
END {
    Write-Host 'Maester tests completed!'
}
