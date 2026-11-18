function Test-MtAdComputerUnconstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts computers with unconstrained delegation configured.

    .DESCRIPTION
    Unconstrained delegation allows a service to impersonate a user to any other service.
    This is a high-risk configuration on non-domain-controller computers. Domain
    controllers are reported separately but excluded from the assessed population.
    Managed service accounts are also assessed and reported separately from device percentages.

    Security Risk:
    - Unconstrained delegation allows full impersonation of authenticated users
    - If a computer with unconstrained delegation is compromised, attackers can
      impersonate any user who authenticates to that computer
    - Should be replaced with constrained or resource-based constrained delegation

    .EXAMPLE
    Test-MtAdComputerUnconstrainedDelegationCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerUnconstrainedDelegationCount
    #>
    [MaesterTest(
        Id = 'AD-DCOMP-01',
        Title = 'Non-DC computers and managed service accounts should not have unconstrained delegation',
        Product = 'ad',
        Feature = 'computers',
        Area = 'authentication',
        ResourceType = 'Computer',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1558', 'T1550.003'),
        Control = 'nist-800-53-r5:AC-6',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:msDS-ManagedServiceAccount:ReadProperty', 'ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount:ReadProperty', 'ActiveDirectory:Ldap:msDS-DelegatedManagedServiceAccount:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerUnconstrainedDelegationCount"
    $adState = Get-MtADDomainState -Categories @('Computers', 'DomainControllers', 'ServiceAccounts')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState -or $null -eq $adState.Computers -or $null -eq $adState.DomainControllers -or $null -eq $adState.ServiceAccounts) {
        throw 'Computer and domain controller inventories are required to assess unconstrained delegation.'
    }
    Write-Verbose "Filtering/counting computer unconstrained delegation count"

    $computers = $adState.Computers
    $domainControllers = $adState.DomainControllers
    if (@($computers).Count -eq 0 -or @($domainControllers).Count -eq 0) {
        throw 'Computer and domain controller inventories must not be empty when assessing delegation.'
    }

    # Only the collected server inventory establishes DC identity, never a claimed primary group.
    $nonDcComputers = @($computers | Where-Object {
            -not (Test-MtAdDomainControllerAccount -Account $_ -DomainControllers $domainControllers)
        })
    $managedAccounts = @($adState.ServiceAccounts)
    if (@(@($nonDcComputers) + @($managedAccounts) | Where-Object { $null -eq $_.TrustedForDelegation }).Count -gt 0) {
        throw 'Unconstrained delegation flag is missing for non-DC computers.'
    }

    # Find computers with unconstrained delegation
    $unconstrainedComputers = $computers | Where-Object { $_.TrustedForDelegation -eq $true }
    $unconstrainedCount = ($unconstrainedComputers | Measure-Object).Count

    # Count DCs vs non-DCs with unconstrained delegation
    $nonDcUnconstrained = @($nonDcComputers | Where-Object { $_.TrustedForDelegation -eq $true })
    $dcUnconstrainedCount = $unconstrainedCount - $nonDcUnconstrained.Count
    $nonDcUnconstrainedCount = $nonDcUnconstrained.Count
    $managedUnconstrained = @($managedAccounts | Where-Object { $_.TrustedForDelegation -eq $true })
    $unverifiedDcGroups = @($nonDcComputers | Where-Object { $_.PrimaryGroupId -in 516, 521 })

    $totalComputers = @($computers).Count
    $totalNonDcComputers = $nonDcComputers.Count
    $testResult = $nonDcUnconstrainedCount -eq 0 -and $managedUnconstrained.Count -eq 0

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Computers | $totalComputers |" + "`n"
    $result += "| Computers with Unconstrained Delegation | $unconstrainedCount |" + "`n"
    $result += "| Domain Controllers with Unconstrained Delegation | $dcUnconstrainedCount |" + "`n"
    $result += "| Non-DC Computers with Unconstrained Delegation | $nonDcUnconstrainedCount |" + "`n"
    $result += "| Total Non-DC Computers | $totalNonDcComputers |" + "`n"
    $result += "| Managed Service Accounts | $($managedAccounts.Count) |`n"
    $result += "| Managed Service Accounts with Unconstrained Delegation | $($managedUnconstrained.Count) |`n"
    $result += "| Non-DC Computers Claiming DC Primary Groups | $($unverifiedDcGroups.Count) |`n"
    $percentage = if ($totalNonDcComputers -gt 0) { [Math]::Round(($nonDcUnconstrainedCount / $totalNonDcComputers) * 100, 2) } else { 0 }
    $result += "| Non-DC Percentage with Unconstrained Delegation | $percentage% |" + "`n"
    if (-not $testResult) {
        $result += "`n| Non-DC Computer | Operating System |`n| --- | --- |`n"
        foreach ($computer in @($nonDcUnconstrained | Select-Object -First 10)) {
            $name = [string]$computer.Name -replace '\|', '\|' -replace '[\r\n]', ' '
            $os = [string]$computer.OperatingSystem -replace '\|', '\|' -replace '[\r\n]', ' '
            $result += "| $name | $os |`n"
        }
        $result += "`n| Managed Account with Unconstrained Delegation |`n| --- |`n"
        foreach ($account in $managedUnconstrained) {
            $name = ([string]$account.Name).Replace('|', '&#124;') -replace '[\r\n]+', ' '
            $result += "| $name |`n"
        }
    }
    Write-Verbose "Counts computed"

    $summary = if ($testResult) { 'Well done. No non-DC computers or managed service accounts have unconstrained delegation.' } else { 'Non-DC computers or managed service accounts with unconstrained delegation were found. Migrate their services to constrained delegation and remove unconstrained delegation.' }
    if ($unverifiedDcGroups.Count -gt 0) { $summary += " $($unverifiedDcGroups.Count) computer(s) claim a DC primary group without inventory evidence; review AD-COMP-04. They were not excluded." }
    $testResultMarkdown = "$summary`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdComputerUnconstrainedDelegationCount"

    return $testResult
}
