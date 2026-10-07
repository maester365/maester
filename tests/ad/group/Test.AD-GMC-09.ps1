function Test-MtAdGroupEmptyNonPrivilegedDetails {
    <#
    .SYNOPSIS
    Details of empty non-privileged groups in Active Directory.

    .DESCRIPTION
    This test lists groups that have no members and are not privileged
    (do not have adminCount = 1). These groups may be candidates for cleanup
    as they serve no purpose in access control and clutter the directory.

    .EXAMPLE
    Test-MtAdGroupEmptyNonPrivilegedDetails

    Returns $true if data is retrievable.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupEmptyNonPrivilegedDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-GMC-09',
        Title = 'Empty non-privileged group details should be investigated',
        Severity = 'Info',
        Category = 'Active Directory - Group Members',
        Tag = ('AD.GMC', 'AD.Group'),
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories @('Groups')
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $groups = $adState.Groups

    $protocolConnection = $null
    $emptyNonPrivilegedGroups = @()

    try {
        $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

        foreach ($group in $groups) {
            try {
                $members = @(Get-MtLdapGroupMember -Connection $protocolConnection -GroupDistinguishedName $group.DistinguishedName)
                $memberCount = ($members | Measure-Object).Count

                if ($memberCount -eq 0 -and $group.adminCount -ne 1) {
                    $emptyNonPrivilegedGroups += [PSCustomObject]@{
                        Name              = $group.Name
                        DistinguishedName = $group.DistinguishedName
                        GroupCategory     = $group.GroupCategory
                        GroupScope        = $group.GroupScope
                        Created           = $group.createTimeStamp
                        Modified          = $group.modifyTimeStamp
                    }
                }
            } catch {
                Write-Verbose "Could not check members for group $($group.Name): $($_.Exception.Message)"
            }
        }
    } finally {
        if ($null -ne $protocolConnection) {
            $protocolConnection.Dispose()
        }
    }

    $testResult = $true

    $result = "### Empty Non-Privileged Groups" + "`n" + "`n"

    if ($emptyNonPrivilegedGroups.Count -eq 0) {
        $result += "> No empty non-privileged groups found." + "`n" + "`n"
        $result += "All non-privileged groups have at least one member." + "`n" + "`n"
    } else {
        $result += "**Total Empty Non-Privileged Groups:** $($emptyNonPrivilegedGroups.Count)" + "`n" + "`n"
        $result += "| Group Name | Scope | Category | Created | Last Modified |" + "`n"
        $result += "| --- | --- | --- | --- | --- |" + "`n"

        $sortedGroups = $emptyNonPrivilegedGroups | Sort-Object Name

        foreach ($group in $sortedGroups | Select-Object -First 50) {
            $created = if ($group.Created) { $group.Created.ToString('yyyy-MM-dd') } else { 'N/A' }
            $modified = if ($group.Modified) { $group.Modified.ToString('yyyy-MM-dd') } else { 'N/A' }

            $result += "| $($group.Name) | $($group.GroupScope) | $($group.GroupCategory) | $created | $modified |" + "`n"
        }

        if ($emptyNonPrivilegedGroups.Count -gt 50) {
            $remaining = $emptyNonPrivilegedGroups.Count - 50
            $result += "`n> *... and $remaining more groups*" + "`n"
        }
    }

    $testResultMarkdown = $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    return $testResult
}
