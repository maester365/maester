function Test-MtAdDaclPrivilegedAllowAceCount {
    <#
    .SYNOPSIS
    Counts privileged allow ACEs in collected DACL data.

    .DESCRIPTION
    This test identifies allow ACEs that include high-impact Active Directory rights
    such as GenericAll, WriteDacl, WriteOwner, or ExtendedRight. These rights can
    enable broad control over directory objects and should be monitored carefully.

    .EXAMPLE
    Test-MtAdDaclPrivilegedAllowAceCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclPrivilegedAllowAceCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $privilegedRights = @('GenericAll', 'WriteDacl', 'WriteOwner', 'ExtendedRight')
    $getPrivilegedRights = {
        param($rightsText)

        @(
            foreach ($right in $privilegedRights) {
                if ([string]$rightsText -match "(^|,\s*)$right(,|$)") {
                    $right
                }
            }
        )
    }

    $daclEntries = @($adState.DaclEntries)
    $privilegedAllowEntries = @(
        foreach ($entry in $daclEntries) {
            if ($entry.AccessControlType -notlike 'AccessAllowed*') {
                continue
            }

            $matchedRights = @(& $getPrivilegedRights $entry.ActiveDirectoryRights)
            if ($matchedRights.Count -gt 0) {
                [PSCustomObject]@{
                    ObjectDN = $entry.ObjectDN
                    ObjectClass = $entry.ObjectClass
                    ObjectName = $entry.ObjectName
                    IdentityReference = $entry.IdentityReference
                    MatchedRights = $matchedRights
                }
            }
        }
    )

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DACL ACEs | $((@($daclEntries) | Measure-Object).Count) |`n"
    $result += "| Privileged allow ACEs | $($privilegedAllowEntries.Count) |`n"
    $result += "| Distinct objects with privileged allow ACEs | $(@($privilegedAllowEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } | Select-Object -ExpandProperty ObjectDN -Unique).Count) |`n"
    $result += "| Distinct identities with privileged allow ACEs | $(@($privilegedAllowEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } | Select-Object -ExpandProperty IdentityReference -Unique).Count) |`n"

    foreach ($right in $privilegedRights) {
        $rightCount = @($privilegedAllowEntries | Where-Object { $_.MatchedRights -contains $right }).Count
        $result += "| ACEs containing $right | $rightCount |`n"
    }

    $testResultMarkdown = "This informational test counts allow ACEs that grant high-impact Active Directory rights.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


