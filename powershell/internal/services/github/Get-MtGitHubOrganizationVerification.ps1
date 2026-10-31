function Get-MtGitHubOrganizationVerification {
    <#
    .SYNOPSIS
    Internal: Reads organization profile verification with positive enterprise applicability evidence.
    #>
    [CmdletBinding()]
    param()
    $login = $__MtSession.GitHubConnection.Organization
    $provided = $__MtSession.MaesterConfig.GlobalSettings.PSObject.Properties['GitHubOrganization']
    if ($provided -and $provided.Value -isnot [string]) { throw 'GitHubOrganization must be a string.' }
    $configured = Get-MtSetting -Name GitHubOrganization -Verbose:$false
    if ($configured -isnot [string] -or (-not [string]::IsNullOrWhiteSpace($configured) -and $configured -ne $login)) { throw 'GitHubOrganization must match the connected organization.' }
    $enterpriseSetting = $__MtSession.MaesterConfig.GlobalSettings.PSObject.Properties['GitHubEnterprise']
    if ($enterpriseSetting -and $null -ne $enterpriseSetting.Value -and $enterpriseSetting.Value -isnot [string]) { throw 'GitHubEnterprise must be an enterprise slug string.' }
    if ([string]::IsNullOrWhiteSpace((Get-MtSetting -Name GitHubEnterprise -Verbose:$false))) { return [pscustomobject]@{ Verdict = 'Indeterminate'; Detail = 'Indeterminate: configure the explicit GitHubEnterprise applicability context.' } }
    $query = 'query MaesterCisVerification($login:String!){organization(login:$login){id login isVerified}}'
    $evidence = Invoke-MtGitHubGraphQLRequest -Query $query -Variables @{ login = $login } -OperationName MaesterCisVerification
    $organization = $evidence.Data.organization
    if ($evidence.Errors.Count -gt 0 -or $null -eq $organization -or $organization.GetType() -ne [System.Management.Automation.PSCustomObject] -or $organization.id -isnot [string] -or [string]::IsNullOrWhiteSpace($organization.id) -or $organization.login -isnot [string] -or $organization.login -ne $login -or $organization.isVerified -isnot [bool]) {
        return [pscustomobject]@{ Verdict = 'Indeterminate'; Detail = 'Indeterminate: organization profile verification evidence is unavailable or unusable.' }
    }
    $association = Get-MtGitHubEnterprise -Purpose Association -OrganizationId $organization.id -OrganizationLogin $login
    if ($association.Verdict -ne 'Passed') { return $association }
    $displayLogin = [System.Net.WebUtility]::HtmlEncode([string]$login).Replace('|', '&#124;').Replace('`', '&#96;') -replace '[\r\n]', ' '
    if ($displayLogin.Length -gt 160) { $displayLogin = $displayLogin.Substring(0, 160) }
    $summary = if ($organization.isVerified) { 'Well done. The organization has verified its profile email and website.' } else { 'Verify the organization profile domains to obtain its Verified badge.' }
    return [pscustomobject]@{
        Verdict = $(if ($organization.isVerified) { 'Passed' } else { 'Failed' })
        Detail = "$summary`n`nOrganization: ``$displayLogin`` at ``$($__MtSession.GitHubConnection.ApiBaseUri)``. isVerified: ``$($organization.isVerified)``.`n`n$($association.Detail)`n`nProfile observed UTC: $($evidence.StartedUtc.ToString('o')) through $($evidence.CompletedUtc.ToString('o')). Only this organization is assessed; no enterprise-wide coverage is claimed."
    }
}
