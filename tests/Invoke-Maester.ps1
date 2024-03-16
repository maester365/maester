<#
 .Synopsis
    Script to run Maester tests and generate the report.

 .Description
    MFA for risky sign-ins conditional access policy can be used to require MFA for all users in the tenant.

 .Example
    ./Invoke-Maester.ps1
#>

[CmdletBinding()]
param (

    # The Pester test results returned from Invoke-Pester -PassThru
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
    [string[]] $Tag = "All",

    # The path to the html file to be generated
    [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true)]
    [string] $OutputFolder = "./test-results"
)

$motd = @"

.___  ___.      ___       _______     _______.___________. _______ .______         ____    ____  ___      __
|   \/   |     /   \     |   ____|   /       |           ||   ____||   _  \        \   \  /   / / _ \    /_ |
|  \  /  |    /  ^  \    |  |__     |   (--------|  |----``|  |__   |  |_)  |        \   \/   / | | | |    | |
|  |\/|  |   /  /_\  \   |   __|     \   \       |  |     |   __|  |      /          \      /  | | | |    | |
|  |  |  |  /  _____  \  |  |____.----)   |      |  |     |  |____ |  |\  \----.      \    /   | |_| |  __| |
|__|  |__| /__/     \__\ |_______|_______/       |__|     |_______|| _| ``._____|       \__/     \___/  (__)_|


"@
Write-Host -ForegroundColor Green -Object $motd

# Create unique file name for the test results with current date and time
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null # Create the output folder if it doesn't exist
$htmlFileName = Join-Path $OutputFolder "TestResults-$timestamp.html"

#--------------------------------------------------------------

Connect-MtGraph # Short cmdlet for `Connect-MgGraph -Scopes (Get-MtGraphScopes)`

Clear-MtGraphCache # Reset the cache to avoid stale data

$pesterResults = Invoke-Pester -PassThru -TagFilter $Tag # Run Pester tests

Export-MtHtmlReport -PesterResults $pesterResults -OutputHtmlPath $htmlFileName # Export test results to HTML

Write-Output "Test file generated at $htmlFileName"
#--------------------------------------------------------------

if ([Environment]::UserInteractive) {
    # Open test results in default browser
    Invoke-Item $htmlFileName
}