function Test-MtAdComputerUnconstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts computers with unconstrained delegation configured.

    .DESCRIPTION
    Unconstrained delegation allows a service to impersonate a user to any other service.
    This is a high-risk configuration on non-domain-controller computers. Domain
    controllers are reported separately but excluded from the assessed population.

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
        Title = 'Non-DC computers should not have unconstrained delegation',
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
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerUnconstrainedDelegationCount"
    $adState = Get-MtADDomainState -Categories @('Computers', 'DomainControllers')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState -or $null -eq $adState.Computers -or $null -eq $adState.DomainControllers) {
        throw 'Computer and domain controller inventories are required to assess unconstrained delegation.'
    }
    Write-Verbose "Filtering/counting computer unconstrained delegation count"

    $computers = $adState.Computers
    $domainControllers = $adState.DomainControllers
    if (@($computers).Count -eq 0 -or @($domainControllers).Count -eq 0) {
        throw 'Computer and domain controller inventories must not be empty when assessing delegation.'
    }

    # DCs are identified by primary group, serverReference DN or matching DNS
    # host name. Name alone is used only when the DC has neither reference nor DNS.
    $dcReferences = @($domainControllers | Where-Object { $_.ServerReference } | ForEach-Object { $_.ServerReference })
    $dcDnsNames = @($domainControllers | Where-Object { $_.DnsHostName } | ForEach-Object { $_.DnsHostName })
    $dcWithoutReference = @($domainControllers | Where-Object { -not $_.ServerReference })
    $nonDcComputers = @($computers | Where-Object {
            $computer = $_
            $isDc = $computer.PrimaryGroupId -in @(516, 521) -or $dcReferences -contains $computer.DistinguishedName
            if (-not $isDc -and $computer.DnsHostName) { $isDc = $dcDnsNames -contains $computer.DnsHostName }
            if (-not $isDc -and -not $computer.DnsHostName -and $computer.Name) {
                $isDc = @($dcWithoutReference | Where-Object { -not $_.DnsHostName -and $_.Name -eq $computer.Name }).Count -gt 0
            }
            -not $isDc
        })
    if (@($nonDcComputers | Where-Object { $null -eq $_.TrustedForDelegation }).Count -gt 0) {
        throw 'Unconstrained delegation flag is missing for non-DC computers.'
    }

    # Find computers with unconstrained delegation
    $unconstrainedComputers = $computers | Where-Object { $_.TrustedForDelegation -eq $true }
    $unconstrainedCount = ($unconstrainedComputers | Measure-Object).Count

    # Count DCs vs non-DCs with unconstrained delegation
    $nonDcUnconstrained = @($nonDcComputers | Where-Object { $_.TrustedForDelegation -eq $true })
    $dcUnconstrainedCount = $unconstrainedCount - $nonDcUnconstrained.Count
    $nonDcUnconstrainedCount = $nonDcUnconstrained.Count

    $totalComputers = @($computers).Count
    $totalNonDcComputers = $nonDcComputers.Count
    $testResult = $nonDcUnconstrainedCount -eq 0

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Computers | $totalComputers |" + "`n"
    $result += "| Computers with Unconstrained Delegation | $unconstrainedCount |" + "`n"
    $result += "| Domain Controllers with Unconstrained Delegation | $dcUnconstrainedCount |" + "`n"
    $result += "| Non-DC Computers with Unconstrained Delegation | $nonDcUnconstrainedCount |" + "`n"
    $result += "| Total Non-DC Computers | $totalNonDcComputers |" + "`n"
    $percentage = if ($totalNonDcComputers -gt 0) { [Math]::Round(($nonDcUnconstrainedCount / $totalNonDcComputers) * 100, 2) } else { 0 }
    $result += "| Non-DC Percentage with Unconstrained Delegation | $percentage% |" + "`n"
    if (-not $testResult) {
        $result += "`n| Non-DC Computer | Operating System |`n| --- | --- |`n"
        foreach ($computer in @($nonDcUnconstrained | Select-Object -First 10)) {
            $name = [string]$computer.Name -replace '\|', '\|' -replace '[\r\n]', ' '
            $os = [string]$computer.OperatingSystem -replace '\|', '\|' -replace '[\r\n]', ' '
            $result += "| $name | $os |`n"
        }
    }
    Write-Verbose "Counts computed"

    $summary = if ($testResult) { 'Well done. No non-DC computers have unconstrained delegation.' } else { 'Non-DC computers with unconstrained delegation were found. Migrate their services to constrained delegation and remove unconstrained delegation.' }
    $testResultMarkdown = "$summary`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdComputerUnconstrainedDelegationCount"

    return $testResult
}
