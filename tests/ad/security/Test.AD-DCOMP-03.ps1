function Test-MtAdComputerNonDcConstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts non-domain controller computers with constrained delegation configured.

    .DESCRIPTION
    Inventories classic Kerberos constrained delegation target SPNs, the
    TrustedToAuthForDelegation protocol-transition flag, and presence of an RBCD
    security descriptor on non-DC computer objects. RBCD presence does not
    identify allowed principals or establish effective access. These categories
    can overlap and do not include delegation configured on user accounts.

    Security Considerations:
    - Constrained delegation is safer than unconstrained but still carries risk
    - Should be limited to specific required scenarios (e.g., web applications)
    - Each computer with constrained delegation should be reviewed
    - Consider using resource-based constrained delegation as a more secure alternative

    .EXAMPLE
    Test-MtAdComputerNonDcConstrainedDelegationCount

    Reports an Investigate inventory when the required computer fields are available.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerNonDcConstrainedDelegationCount
    #>
    [MaesterTest(
        Id = 'AD-DCOMP-03',
        Title = 'Non-DC computer constrained delegation should be investigated',
        Product = 'ad',
        Feature = 'computers',
        Area = 'authentication',
        ResourceType = 'Computer',
        Severity = 'Info',
        Mitre = ('T1558', 'T1550.003'),
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerNonDcConstrainedDelegationCount"
    $adState = Get-MtADDomainState -Categories @('Computers', 'DomainControllers')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState -or $null -eq $adState.Computers -or $null -eq $adState.DomainControllers) {
        throw 'Computer and domain controller inventories are required to review constrained delegation.'
    }
    Write-Verbose "Filtering/counting computer non dc constrained delegation count"

    $computers = $adState.Computers
    $domainControllers = $adState.DomainControllers
    if (@($computers).Count -eq 0 -or @($domainControllers).Count -eq 0) {
        throw 'Computer and domain controller inventories must not be empty when reviewing constrained delegation.'
    }

    # Match DC computer DNs to serverReference first. The primary group also
    # identifies writable DCs (516) and RODCs (521). DNS names also identify
    # DCs; a name alone is used only when the DC has no reference or DNS name.
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
    if (@($nonDcComputers | Where-Object {
                -not $_.PSObject.Properties['AllowedToDelegateTo'] -or $null -eq $_.AllowedToDelegateTo -or
                -not $_.PSObject.Properties['HasResourceBasedConstrainedDelegation'] -or $null -eq $_.HasResourceBasedConstrainedDelegation -or
                -not $_.PSObject.Properties['TrustedToAuthForDelegation'] -or $null -eq $_.TrustedToAuthForDelegation
            }).Count -gt 0) {
        throw 'Required delegation fields are missing from the non-DC computer inventory; a zero count cannot be trusted.'
    }

    $classicKcd = @($nonDcComputers | Where-Object { @($_.AllowedToDelegateTo).Count -gt 0 })
    $protocolTransition = @($nonDcComputers | Where-Object { $_.TrustedToAuthForDelegation -eq $true })
    $rbcdPresent = @($nonDcComputers | Where-Object { $_.HasResourceBasedConstrainedDelegation -eq $true })
    $reviewComputers = @($nonDcComputers | Where-Object {
            @($_.AllowedToDelegateTo).Count -gt 0 -or $_.TrustedToAuthForDelegation -eq $true -or $_.HasResourceBasedConstrainedDelegation -eq $true
        })
    $totalNonDcComputers = $nonDcComputers.Count

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Non-DC Computers | $totalNonDcComputers |" + "`n"
    $result += "| Non-DC Computers with Classic KCD Target SPNs | $($classicKcd.Count) |`n"
    $result += "| Non-DC Computers with Protocol Transition Flag | $($protocolTransition.Count) |`n"
    $result += "| Non-DC Computers with RBCD Descriptor Present | $($rbcdPresent.Count) |`n"
    $result += "| Distinct Non-DC Computers with One or More Indicators | $($reviewComputers.Count) |`n"
    if ($totalNonDcComputers -gt 0) {
        $percentage = [Math]::Round(($reviewComputers.Count / $totalNonDcComputers) * 100, 2)
        $result += "| Percentage of Non-DC Computers with an Indicator | $percentage% |`n"
    }

    if ($reviewComputers.Count -gt 0) {
        $result += "`n**Non-DC Computers to Review (Top 10):**`n`n"
        $result += "| Computer | Classic KCD Target SPNs | Protocol Transition Flag | RBCD Descriptor Present |`n| --- | --- | --- | --- |`n"
        foreach ($computer in $reviewComputers | Select-Object -First 10) {
            $name = [string]$computer.Name -replace '\|', '\|' -replace '[\r\n]', ' '
            $spns = [string](@($computer.AllowedToDelegateTo) -join ', ') -replace '\|', '\|' -replace '[\r\n]', ' '
            if (-not $spns) { $spns = 'None' }
            $result += "| $name | $spns | $($computer.TrustedToAuthForDelegation) | $($computer.HasResourceBasedConstrainedDelegation) |`n"
        }
        if ($reviewComputers.Count -gt 10) {
            $result += "| ... and $($reviewComputers.Count - 10) more | | | |`n"
        }
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Review non-DC classic KCD target SPNs, protocol transition and RBCD descriptor presence. RBCD presence does not identify allowed principals or prove effective access; categories can overlap.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdComputerNonDcConstrainedDelegationCount"

    return $true
}
