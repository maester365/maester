param (
    [Parameter(Mandatory=$true, HelpMessage="The Entra Tenant Id")]
    [string]$TenantId,

    [Parameter(Mandatory=$true, HelpMessage="The Client Id of the Service Principal")]
    [string]$ClientId,

    [Parameter(Mandatory=$true, HelpMessage="The path for the files and pester tests")]
    [string]$Path,

    [Parameter(Mandatory=$false, HelpMessage="The Pester verbosity level")]
    [ValidateSet("None", "Normal", "Detailed", "Diagnostic")]
    [string]$PesterVerbosity = "None",

    [Parameter(Mandatory=$false, HelpMessage="The mail user id")]
    [string]$MailUser = "",

    [Parameter(Mandatory=$false, HelpMessage="The mail recipients seperated by comma")]
    [string]$MailRecipients = "",

    [Parameter(Mandatory=$false, HelpMessage="The test result uri")]
    [string]$TestResultURI = "",

    [Parameter(Mandatory=$false, HelpMessage="The tags to include in the tests")]
    [string]$IncludeTags = "",

    [Parameter(Mandatory=$false, HelpMessage="The tags to exclude in the tests")]
    [string]$ExcludeTags = "",

    [Parameter(Mandatory=$false, HelpMessage="Include Exchange Online tests")]
    [bool]$IncludeExchange = $true,

    [Parameter(Mandatory=$false, HelpMessage="Include Teams tests")]
    [bool]$IncludeTeams = $true,

    [Parameter(Mandatory=$false, HelpMessage="Install preview version of Maester")]
    [bool]$Preview = $false,

    [Parameter(Mandatory=$false, HelpMessage="Disable telemetry")]
    [bool]$DisableTelemetry = $false,

    [Parameter(Mandatory=$false, HelpMessage="Add test results to GitHub step summary")]
    [bool]$GitHubStepSummary = $false
)

BEGIN{
    Write-Host "Starting Maester tests"
}
PROCESS{
    $graphToken = Get-AzAccessToken -ResourceUrl  "https://graph.microsoft.com"

    # Connect to Microsoft Graph with the token as secure string
    $accessToken = $graphToken.Token | ConvertTo-SecureString -AsPlainText -Force
    Connect-MgGraph -AccessToken $accessToken -NoWelcome

    # Check if we need to connect to Exchange Online
    if ($IncludeExchange) {
        Install-Module ExchangeOnlineManagement -Force
        Import-Module ExchangeOnlineManagement

        $outlookToken = Get-AzAccessToken -ResourceUrl 'https://outlook.office365.com'
        Connect-ExchangeOnline -AccessToken $outlookToken -AppId $ClientId -Organization $TenantId -ShowBanner:$false
    }else{
        Write-Host "Exchange Online tests will be skipped."
    }

    # Check if we need to connect to Exchange Online
    if ($IncludeTeams) {
        Install-Module MicrosoftTeams -Force
        Import-Module MicrosoftTeams

        $teamsToken = Get-AzAccessToken -ResourceUrl "48ac35b8-9aa8-4d74-927d-1f4a14a0b239"

        $tokens = @($graphToken.Token, $teamsToken.Token)
        Connect-MicrosoftTeams -AccessTokens $tokens -Verbose
    }else{
        Write-Host "Teams tests will be skipped."
    }

    # Install Maester
    if ($Preview){
    Install-Module Maester -AllowPrerelease -Force
    } else {
    Install-Module Maester -Force
    }

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
            Write-Warning "Mail recipients are not provided. Skipping mail notification."
        }
    }

    # Check if disable telemetry is provided
    if ($DisableTelemetry ) {
        $MaesterParameters.Add( 'DisableTelemetry', $true )
    }

    # Run Maester tests
    $results = Invoke-Maester @MaesterParameters

    if($GitHubStepSummary) {
        # Add step summary
        $summary = Get-Content test-results/test-results.md
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $summary
    }
}
END{
    Write-Host "Maester tests completed!"
}