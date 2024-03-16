[CmdletBinding()]
param ($Tag = "All")

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
$outpuFolder = "./test-results"
if ( -not (Test-Path -Path $outpuFolder) ) {
    New-Item -Path $outpuFolder -ItemType Directory
}
$htmlFileName = Join-Path $outpuFolder "TestResults-$timestamp.html"


#--------------------------------------------------------------

Connect-MtGraph # Short cmdlet for `Connect-MgGraph -Scopes (Get-MtGraphScopes)`

Clear-MtGraphCache # Reset the cache to avoid stale data

$pesterResults = Invoke-Pester -PassThru -TagFilter $Tag # Run Pester tests

Export-MtHtmlReport -PesterResults $pesterResults -OutputHtmlPath $htmlFileName # Export test results to HTML

#--------------------------------------------------------------

if ([Environment]::UserInteractive) {
    # Open test results in default browser
    Invoke-Item $htmlFileName
} else {
    Write-Output "Test file generated at $htmlFileName"
}