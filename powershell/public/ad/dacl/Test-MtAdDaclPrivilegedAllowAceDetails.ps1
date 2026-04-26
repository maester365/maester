function Test-MtAdDaclPrivilegedAllowAceDetails {
    <#
    .SYNOPSIS
    Returns details for privileged allow ACEs in collected DACL data.

    .DESCRIPTION
    This test identifies allow ACEs that contain high-impact Active Directory rights
    such as GenericAll, WriteDacl, WriteOwner, or ExtendedRight and groups them by
    object. The output provides a concise breakdown of where privileged rights appear.

    .EXAMPLE
    Test-MtAdDaclPrivilegedAllowAceDetails

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclPrivilegedAllowAceDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclPrivilegedAllowAceDetails"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting dacl privileged allow ace details"

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
                    ObjectDN          = $entry.ObjectDN
                    ObjectClass       = $entry.ObjectClass
                    ObjectName        = $entry.ObjectName
                    IdentityReference = $entry.IdentityReference
                    MatchedRights     = $matchedRights
                }
            }
        }
    )

    $objectBreakdown = @(
        $privilegedAllowEntries |
        Group-Object ObjectDN |
        Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
        ForEach-Object {
            $entriesForObject = @($_.Group)
            $firstEntry = $entriesForObject | Select-Object -First 1
            [PSCustomObject]@{
                ObjectName    = $firstEntry.ObjectName
                ObjectClass   = $firstEntry.ObjectClass
                ObjectDN      = if ([string]::IsNullOrWhiteSpace($_.Name)) { '[Unknown ObjectDN]' } else { $_.Name }
                AceCount      = $_.Count
                IdentityCount = @(
                    $entriesForObject |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
                    Select-Object -ExpandProperty IdentityReference -Unique
                ).Count
                Rights        = (@(
                        $entriesForObject |
                        ForEach-Object { $_.MatchedRights } |
                        Sort-Object -Unique
                    ) -join ', ')
            }
        }
    )

    $testResult = $true

    $table = "| Object Name | Object Class | ACE Count | Distinct Identities | Privileged Rights | Object DN |`n"
    $table += "| --- | --- | --- | --- | --- | --- |`n"

    foreach ($item in $objectBreakdown) {
        $objectName = [string]$item.ObjectName
        if ([string]::IsNullOrWhiteSpace($objectName)) {
            $objectName = '[Unnamed Object]'
        }
        $objectName = $objectName -replace '\|', '\\&#124;'

        $objectClass = [string]$item.ObjectClass
        $objectClass = $objectClass -replace '\|', '\\&#124;'

        $rights = [string]$item.Rights
        $rights = $rights -replace '\|', '\\&#124;'

        $objectDn = [string]$item.ObjectDN
        $objectDn = $objectDn -replace '\|', '\\&#124;'

        $table += "| $objectName | $objectClass | $($item.AceCount) | $($item.IdentityCount) | $rights | $objectDn |`n"
    }

    if ($objectBreakdown.Count -eq 0) {
        $table += "| No privileged allow ACEs found |  | 0 | 0 |  |  |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "This informational test groups privileged allow ACEs by object and summarizes the rights observed.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdDaclPrivilegedAllowAceDetails"
    return $testResult
}


