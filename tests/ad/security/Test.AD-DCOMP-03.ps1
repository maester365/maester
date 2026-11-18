function Test-MtAdComputerNonDcConstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts non-domain controller computers with constrained delegation configured.

    .DESCRIPTION
    Inventories classic Kerberos constrained delegation target SPNs, the
    TrustedToAuthForDelegation protocol-transition flag, and presence of an RBCD
    security descriptor on non-DC computers and sMSA, gMSA and dMSA objects. RBCD presence does not
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
        Title = 'Non-DC computer and managed account constrained delegation should be investigated',
        Product = 'ad',
        Feature = 'computers',
        Area = 'authentication',
        ResourceType = 'Computer',
        Severity = 'Info',
        Mitre = ('T1558', 'T1550.003'),
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:msDS-ManagedServiceAccount:ReadProperty', 'ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount:ReadProperty', 'ActiveDirectory:Ldap:msDS-DelegatedManagedServiceAccount:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerNonDcConstrainedDelegationCount"
    $adState = Get-MtADDomainState -Categories @('Computers', 'DomainControllers', 'ServiceAccounts')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState -or $null -eq $adState.Computers -or $null -eq $adState.DomainControllers -or $null -eq $adState.ServiceAccounts) {
        throw 'Computer and domain controller inventories are required to review constrained delegation.'
    }
    Write-Verbose "Filtering/counting computer non dc constrained delegation count"

    $computers = $adState.Computers
    $domainControllers = $adState.DomainControllers
    if (@($computers).Count -eq 0 -or @($domainControllers).Count -eq 0) {
        throw 'Computer and domain controller inventories must not be empty when reviewing constrained delegation.'
    }

    # Device inventory stays separate from managed accounts; both are assessed for delegation.
    $nonDcComputers = @($computers | Where-Object {
            -not (Test-MtAdDomainControllerAccount -Account $_ -DomainControllers $domainControllers)
        })
    $managedAccounts = @($adState.ServiceAccounts)
    $nonDcAccounts = @($nonDcComputers) + @($managedAccounts)
    if (@($nonDcAccounts | Where-Object {
                -not $_.PSObject.Properties['AllowedToDelegateTo'] -or $null -eq $_.AllowedToDelegateTo -or
                -not $_.PSObject.Properties['HasResourceBasedConstrainedDelegation'] -or $null -eq $_.HasResourceBasedConstrainedDelegation -or
                -not $_.PSObject.Properties['TrustedToAuthForDelegation'] -or $null -eq $_.TrustedToAuthForDelegation
            }).Count -gt 0) {
        throw 'Required delegation fields are missing from the non-DC computer inventory; a zero count cannot be trusted.'
    }

    $classicKcd = @($nonDcAccounts | Where-Object { @($_.AllowedToDelegateTo).Count -gt 0 })
    $protocolTransition = @($nonDcAccounts | Where-Object { $_.TrustedToAuthForDelegation -eq $true })
    $rbcdPresent = @($nonDcAccounts | Where-Object { $_.HasResourceBasedConstrainedDelegation -eq $true })
    $reviewComputers = @($nonDcAccounts | Where-Object {
            @($_.AllowedToDelegateTo).Count -gt 0 -or $_.TrustedToAuthForDelegation -eq $true -or $_.HasResourceBasedConstrainedDelegation -eq $true
        })
    $totalNonDcComputers = $nonDcComputers.Count
    $totalNonDcAccounts = $nonDcAccounts.Count

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Non-DC Computers | $totalNonDcComputers |" + "`n"
    $result += "| Managed Service Accounts | $($managedAccounts.Count) |`n"
    $result += "| Non-DC Accounts with Classic KCD Target SPNs | $($classicKcd.Count) |`n"
    $result += "| Non-DC Accounts with Protocol Transition Flag | $($protocolTransition.Count) |`n"
    $result += "| Non-DC Accounts with RBCD Descriptor Present | $($rbcdPresent.Count) |`n"
    $result += "| Distinct Non-DC Accounts with One or More Indicators | $($reviewComputers.Count) |`n"
    if ($totalNonDcAccounts -gt 0) {
        $percentage = [Math]::Round(($reviewComputers.Count / $totalNonDcAccounts) * 100, 2)
        $result += "| Percentage of Non-DC Accounts with an Indicator | $percentage% |`n"
    }

    if ($reviewComputers.Count -gt 0) {
        $result += "`n**Non-DC Accounts to Review (Top 10):**`n`n"
        $result += "| Account | Classic KCD Target SPNs | Protocol Transition Flag | RBCD Descriptor Present |`n| --- | --- | --- | --- |`n"
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

    $testResultMarkdown = "Review non-DC computer and managed service account classic KCD target SPNs, protocol transition and RBCD descriptor presence. RBCD presence does not identify allowed principals or prove effective access; categories can overlap.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdComputerNonDcConstrainedDelegationCount"

    return $true
}
