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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $dfsrSubscriptions = $adState.DfsrSubscriptions
    $subscriptionCount = ($dfsrSubscriptions | Measure-Object).Count

    # Get domain controllers for comparison
    $domainControllers = $adState.DomainControllers
    $dcCount = ($domainControllers | Measure-Object).Count

    $testResult = $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| DFS-R Subscription Count | $subscriptionCount |`n"
    $result += "| Domain Controller Count | $dcCount |`n"

    if ($dcCount -gt 0) {
        if ($subscriptionCount -eq $dcCount) {
            $result += "| DFS-R Coverage | Complete (all DCs have subscriptions) |`n"
        } elseif ($subscriptionCount -eq 0) {
            $result += "| DFS-R Coverage | None (may be using FRS) |`n"
        } else {
            $coverage = [Math]::Round(($subscriptionCount / $dcCount) * 100, 2)
            $result += "| DFS-R Coverage | $coverage% (partial) |`n"
        }
    }

    if ($subscriptionCount -gt 0) {
        $result += "`n**DFS-R Subscription Details:**`n`n"
        $result += "| Subscription Name | Distinguished Name |`n"
        $result += "| --- | --- |`n"
        foreach ($sub in $dfsrSubscriptions | Select-Object -First 10) {
            $name = $sub.Name
            $dn = $sub.DistinguishedName
            if ($dn.Length -gt 60) { $dn = $dn.Substring(0, 57) + "..." }
            $result += "| $name | $dn |`n"
        }
        if ($subscriptionCount -gt 10) {
            $result += "| ... | ... ($($subscriptionCount - 10) more) |`n"
        }
    }

    $testResultMarkdown = "DFS-R subscription count has been retrieved. DFS-R is the recommended technology for SYSVOL replication.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


