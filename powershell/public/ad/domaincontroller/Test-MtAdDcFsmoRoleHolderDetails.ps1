function Test-MtAdDcFsmoRoleHolderDetails {
    <#
    .SYNOPSIS
    Provides detailed information about FSMO role holders.

    .DESCRIPTION
    This test lists all domain controllers that hold FSMO (Flexible Single Master Operations)
    roles and which specific roles each DC holds. This provides visibility into the distribution
    of critical directory services operations across your domain controllers.

    .EXAMPLE
    Test-MtAdDcFsmoRoleHolderDetails

    Returns $true if FSMO role data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcFsmoRoleHolderDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $domain = $adState.Domain
    $forest = $adState.Forest
    $dcCount = ($adState.DomainControllers | Measure-Object).Count

    # Get all FSMO role holders
    $fsmoRoles = @{
        'Schema Master' = $forest.SchemaMaster
        'Domain Naming Master' = $forest.DomainNamingMaster
        'PDC Emulator' = $domain.PDCEmulator
        'RID Master' = $domain.RIDMaster
        'Infrastructure Master' = $domain.InfrastructureMaster
    }

    # Group roles by DC
    $dcRoles = @{}
    foreach ($role in $fsmoRoles.Keys) {
        $dc = $fsmoRoles[$role]
        if (-not $dcRoles.ContainsKey($dc)) {
            $dcRoles[$dc] = @()
        }
        $dcRoles[$dc] += $role
    }

    $fsmoHolderCount = ($dcRoles.Keys | Measure-Object).Count

    # Test passes if we successfully retrieved FSMO data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| DCs Holding FSMO Roles | $fsmoHolderCount |`n"
    $result += "| Total FSMO Roles | 5 |`n`n"

    $result += "| Domain Controller | FSMO Roles Held | Role Count |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($dc in ($dcRoles.Keys | Sort-Object)) {
        $roles = $dcRoles[$dc] -join ', '
        $roleCount = $dcRoles[$dc].Count
        $result += "| $dc | $roles | $roleCount |`n"
    }

    $testResultMarkdown = "FSMO role distribution has been analyzed across $fsmoHolderCount domain controller(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
