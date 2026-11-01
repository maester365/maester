function Test-MtCisGitHubEnterprise {
    <#
    .SYNOPSIS
    Internal: Assesses the CIS enterprise notification setting or positive organization association.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('Notification', 'Association')] [string] $Purpose,
        [string] $OrganizationId,
        [string] $OrganizationLogin
    )
    $provided = $__MtSession.MaesterConfig.GlobalSettings.PSObject.Properties['GitHubEnterprise']
    if ($provided -and $null -ne $provided.Value -and $provided.Value -isnot [string]) { throw 'GitHubEnterprise must be an enterprise slug string.' }
    $slug = Get-MtSetting -Name GitHubEnterprise -Verbose:$false
    if ($null -ne $slug -and $slug -isnot [string]) { throw 'GitHubEnterprise must be an enterprise slug string.' }
    if ([string]::IsNullOrWhiteSpace($slug)) { return [pscustomobject]@{ Verdict = 'Indeterminate'; Detail = 'Indeterminate: configure the explicit GitHubEnterprise target.' } }
    $hostUri = $__MtSession.GitHubConnection.ApiBaseUri
    $displaySlug = [System.Net.WebUtility]::HtmlEncode($slug).Replace('|', '&#124;').Replace('`', '&#96;') -replace '[\r\n]', ' '
    if ($displaySlug.Length -gt 160) { $displaySlug = $displaySlug.Substring(0, 160) }
    if ($Purpose -eq 'Notification') {
        $evidence = Get-MtGitHubEnterprise -Slug $slug -Purpose Notification
        $enterprise = $evidence.Data.enterprise
        $value = $enterprise.ownerInfo.notificationDeliveryRestrictionEnabledSetting
        $identityValid = $null -ne $enterprise -and $enterprise.GetType() -eq [System.Management.Automation.PSCustomObject] -and $null -ne $enterprise.ownerInfo -and $enterprise.ownerInfo.GetType() -eq [System.Management.Automation.PSCustomObject] -and $enterprise.id -is [string] -and -not [string]::IsNullOrWhiteSpace($enterprise.id) -and $enterprise.slug -is [string] -and $enterprise.slug -eq $slug
        $verdict = if ($evidence.Errors.Count -gt 0 -or -not $identityValid -or $value -isnot [string] -or $value -cnotin 'ENABLED', 'DISABLED') { 'Indeterminate' } elseif ($value -ceq 'ENABLED') { 'Passed' } else { 'Failed' }
        $summary = switch ($verdict) {
            Passed { 'Well done. The selected enterprise restricts notification delivery to approved or verified domains.' }
            Failed { 'Enable notification restrictions for the selected enterprise.' }
            default { 'Indeterminate: the selected enterprise identity or owner-only notification field is unavailable or unusable.' }
        }
        $displayId = [System.Net.WebUtility]::HtmlEncode([string]$enterprise.id).Replace('|', '&#124;').Replace('`', '&#96;') -replace '[\r\n]', ' '
        if ($displayId.Length -gt 160) { $displayId = $displayId.Substring(0, 160) }
        $displayValue = if ($value -is [string] -and $value -cin 'ENABLED', 'DISABLED') { $value } else { 'unavailable' }
        $detail = "$summary`n`nAssessment target: enterprise ``$displaySlug`` at ``$hostUri``; returned enterprise ID: ``$displayId``.`n`nNotification setting: ``$displayValue``.`n`nObserved UTC: $($evidence.StartedUtc.ToString('o')) through $($evidence.CompletedUtc.ToString('o')).`n`nThis is an independently targeted enterprise-setting audit. Organization ownership and per-message delivery are not assessed. Organization restrictions can disable when no eligible domains remain."
        return [pscustomobject]@{ Verdict = $verdict; Detail = $detail }
    }
    if ([string]::IsNullOrWhiteSpace($OrganizationId) -or [string]::IsNullOrWhiteSpace($OrganizationLogin)) { throw 'Association requires an organization identity.' }
    $cursor = $null
    $visited = [System.Collections.Generic.HashSet[string]]::new()
    do {
        $evidence = Get-MtGitHubEnterprise -Slug $slug -Purpose Association -OrganizationLogin $OrganizationLogin -After $cursor
        $enterprise = $evidence.Data.enterprise
        $connection = $enterprise.organizations
        if ($evidence.Errors.Count -gt 0 -or $null -eq $enterprise -or $enterprise.GetType() -ne [System.Management.Automation.PSCustomObject] -or $null -eq $connection -or $connection.GetType() -ne [System.Management.Automation.PSCustomObject] -or $connection.nodes -isnot [array] -or $enterprise.slug -isnot [string] -or $enterprise.slug -ne $slug -or $enterprise.id -isnot [string] -or [string]::IsNullOrWhiteSpace($enterprise.id)) { break }
        foreach ($organization in $connection.nodes) {
            if ($null -ne $organization -and $organization.GetType() -eq [System.Management.Automation.PSCustomObject] -and $organization.id -is [string] -and $organization.id -ceq $OrganizationId -and $organization.login -is [string] -and $organization.login -eq $OrganizationLogin) {
                return [pscustomobject]@{ Verdict = 'Passed'; Detail = "Positive association with enterprise ``$displaySlug`` established by organization node ID. Association observed UTC: $($evidence.StartedUtc.ToString('o')) through $($evidence.CompletedUtc.ToString('o'))." }
            }
        }
        if ($connection.pageInfo.hasNextPage -isnot [bool] -or -not $connection.pageInfo.hasNextPage) { break }
        $cursor = $connection.pageInfo.endCursor
        if ($cursor -isnot [string] -or [string]::IsNullOrWhiteSpace($cursor)) { break }
        if (-not $visited.Add($cursor)) { throw 'GitHub enterprise association pagination cycle detected.' }
    } while ($true)
    return [pscustomobject]@{ Verdict = 'Indeterminate'; Detail = 'Indeterminate: a positive association with the selected enterprise could not be established. Absence from visible results is not proof of non-applicability.' }
}
