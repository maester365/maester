function Test-MtGraphRequired {
    <#
    .SYNOPSIS
    Says whether the tests of a run need a Microsoft Graph connection.

    .DESCRIPTION
    Invoke-Maester checks the Graph connection only when this returns $true, so a run of tests that read
    nothing from Graph (Active Directory tests, or a pack that reads a results file) needs no -SkipGraphConnect.

    A run needs Graph when its native plan has a test that declares Service = 'Graph' and runs, or would run
    once Graph is connected (Skipped with ServiceNotConnected), or when it runs Pester-format tests, which do
    not declare their services. Sending the results by mail or to Teams also needs Graph; Invoke-Maester
    checks that before the tests are discovered.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The rows of Resolve-MtNativePlan.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $Plan = @(),
        # The run includes Pester-format test files.
        [Parameter()] [switch] $PesterTest
    )

    if ($PesterTest) { return $true }
    foreach ($row in @($Plan)) {
        if (-not $row -or 'Graph' -notin @($row.Test.Service)) { continue }
        if ($row.Disposition -eq 'Run' -or ($row.Disposition -eq 'Skipped' -and $row.ReasonCode -eq 'ServiceNotConnected')) { return $true }
    }
    return $false
}
