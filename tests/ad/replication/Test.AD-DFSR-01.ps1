function Test-MtAdDfsrSubscriptionCount {
    <#
    .SYNOPSIS
    Retrieves the count of DFS-R subscriptions for SYSVOL replication.

    .DESCRIPTION
    Distributed File System Replication (DFS-R) is used to replicate SYSVOL
    content between domain controllers. Each domain controller participating
    in SYSVOL replication has a DFS-R subscription object in Active Directory.

    This test counts the number of DFS-R subscriptions, which indicates how
    many domain controllers are configured for SYSVOL replication via DFS-R.

    Note: Older domains may use File Replication Service (FRS) instead of DFS-R.
    The migration from FRS to DFS-R is recommended for improved reliability.

    Security Best Practice:
    - Use DFS-R instead of FRS for SYSVOL replication
    - Ensure all domain controllers have DFS-R subscriptions
    - Monitor replication health regularly

    .EXAMPLE
    Test-MtAdDfsrSubscriptionCount

    Returns $true if DFS-R subscription data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDfsrSubscriptionCount
    #>
    [MaesterTest(
        Id = 'AD-DFSR-01',
        Title = 'All domain controllers should have DFS-R subscriptions',
        Product = 'ad',
        Feature = 'replication',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDfsrSubscriptionCount"

    $adState = Get-MtADDomainState -Categories @('DfsrSubscriptions', 'DomainControllers')

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    if ($null -eq $adState.DfsrSubscriptions -or $null -eq $adState.DomainControllers) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $dfsrSubscriptions = $adState.DfsrSubscriptions
    # Scope to SYSVOL subscriptions only — ignore non-SYSVOL DFS-R replication groups
    $sysvolSubscriptions = @($dfsrSubscriptions | Where-Object {
        [string]$_.DistinguishedName -like '*CN=SYSVOL Subscription,CN=Domain System Volume*'
    })
    $subscriptionCount = ($sysvolSubscriptions | Measure-Object).Count

    # Get domain controllers for per-DC comparison
    $domainControllers = $adState.DomainControllers
    $dcCount = ($domainControllers | Measure-Object).Count

    # Build a map of DC names to subscriptions
    $dcSubscriptionMap = @{}
    foreach ($sub in $sysvolSubscriptions) {
        $dn = [string]$sub.DistinguishedName
        # Extract DC name from DN: CN=SYSVOL Subscription...,CN=<DCName>,...
        if ($dn -match 'CN=([^,]+),OU=Domain Controllers') {
            $dcName = $Matches[1]
            $dcSubscriptionMap[$dcName] = $sub
        }
    }

    $missingDcSubscriptions = @()
    $disabledSubscriptions = @()
    foreach ($dc in $domainControllers) {
        $dcName = if ($dc.Name) { $dc.Name } else { $dc.DnsHostName }
        if (-not $dcSubscriptionMap.ContainsKey($dcName)) {
            $missingDcSubscriptions += $dcName
        } else {
            $sub = $dcSubscriptionMap[$dcName]
            $enabled = if ($sub.'msDFSR-Enabled' -is [bool]) { $sub.'msDFSR-Enabled' } else { [string]$sub.'msDFSR-Enabled' -eq 'TRUE' }
            if (-not $enabled) {
                $disabledSubscriptions += $dcName
            }
        }
    }

    $testResult = ($dcCount -gt 0) -and ($missingDcSubscriptions.Count -eq 0) -and ($disabledSubscriptions.Count -eq 0)

    $result = "| Property | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Domain Controller Count | $dcCount |" + "`n"
    $result += "| DFS-R SYSVOL Subscription Count | $subscriptionCount |" + "`n"
    $result += "| DCs Missing Subscription | $($missingDcSubscriptions.Count) |" + "`n"
    $result += "| DCs with Disabled Subscription | $($disabledSubscriptions.Count) |" + "`n"

    if ($missingDcSubscriptions.Count -gt 0) {
        $result += "`n**DCs Missing DFS-R Subscription:**" + "`n" + "`n"
        $result += "| DC Name |" + "`n"
        $result += "| --- |" + "`n"
        foreach ($dcName in $missingDcSubscriptions | Select-Object -First 10) {
            $result += "| $dcName |" + "`n"
        }
    }

    if ($disabledSubscriptions.Count -gt 0) {
        $result += "`n**DCs with Disabled DFS-R Subscription:**" + "`n" + "`n"
        $result += "| DC Name |" + "`n"
        $result += "| --- |" + "`n"
        foreach ($dcName in $disabledSubscriptions | Select-Object -First 10) {
            $result += "| $dcName |" + "`n"
        }
    }

    if ($subscriptionCount -gt 0 -and $missingDcSubscriptions.Count -eq 0 -and $disabledSubscriptions.Count -eq 0) {
        $result += "`n**DFS-R Subscription Details:**" + "`n" + "`n"
        $result += "| Subscription Name | Distinguished Name | Enabled |" + "`n"
        $result += "| --- | --- | --- |" + "`n"
        foreach ($sub in $sysvolSubscriptions | Select-Object -First 10) {
            $name = $sub.Name
            $dn = $sub.DistinguishedName
            $enabled = if ($sub.'msDFSR-Enabled' -is [bool]) { $sub.'msDFSR-Enabled' } else { [string]$sub.'msDFSR-Enabled' -eq 'TRUE' }
            $enabledStr = if ($enabled) { 'Yes' } else { 'No' }
            if ($dn.Length -gt 60) { $dn = $dn.Substring(0, 57) + "..." }
            $result += "| $name | $dn | $enabledStr |" + "`n"
        }
        if ($subscriptionCount -gt 10) {
            $result += "| ... | ... ($($subscriptionCount - 10) more) | |" + "`n"
        }
    }

    $testResultMarkdown = "DFS-R subscription analysis has been performed. DFS-R is the recommended technology for SYSVOL replication.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
