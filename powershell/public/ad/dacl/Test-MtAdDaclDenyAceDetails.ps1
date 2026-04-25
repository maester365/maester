function Test-MtAdDaclDenyAceDetails {
    <#
    .SYNOPSIS
    Returns a breakdown of deny authorization ACEs by object and identity.

    .DESCRIPTION
    This informational test filters DACL data to deny ACEs and groups the results by object and
    identity reference. The output helps administrators understand which principals are explicitly
    denied access to which objects and where deny ACE concentration exists in the directory.

    .EXAMPLE
    Test-MtAdDaclDenyAceDetails

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclDenyAceDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }

    $daclEntries = @($adState.DaclEntries)
    $denyEntries = @($daclEntries | Where-Object { $_.AccessControlType -match 'Deny' })
    $denyAceCount = ($denyEntries | Measure-Object).Count
    $denyGroups = @($denyEntries | Group-Object -Property ObjectDN, IdentityReference | Sort-Object -Property Count, Name -Descending)
    $denyGroupCount = ($denyGroups | Measure-Object).Count
    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Deny ACEs | $denyAceCount |`n"
    $result += "| Object and Identity Combinations | $denyGroupCount |`n`n"

    if ($denyGroupCount -gt 0) {
        $result += "| Object Name | Object Class | Object DN | Identity Reference | Deny ACE Count |`n"
        $result += "| --- | --- | --- | --- | --- |`n"

        foreach ($group in $denyGroups) {
            $sample = $group.Group | Select-Object -First 1
            $objectName = if ($null -ne $sample.ObjectName) { ([string]$sample.ObjectName) -replace '\|', '\\&#124;' } else { '' }
            $objectClass = if ($null -ne $sample.ObjectClass) { ([string]$sample.ObjectClass) -replace '\|', '\\&#124;' } else { '' }
            $objectDn = if ($null -ne $sample.ObjectDN) { ([string]$sample.ObjectDN) -replace '\|', '\\&#124;' } else { '' }
            $identityReference = if ($null -ne $sample.IdentityReference) { ([string]$sample.IdentityReference) -replace '\|', '\\&#124;' } else { '' }
            $result += "| $objectName | $objectClass | $objectDn | $identityReference | $($group.Count) |`n"
        }
    }
    else {
        $result += "**No deny ACEs were identified in the collected DACL data.**`n"
    }

    $testResultMarkdown = "Active Directory DACL deny-ACE details have been compiled. The results are grouped by object and identity reference for review.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
