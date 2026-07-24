function Test-MtHighPrivilegeServicePrincipalsForAllUsers {
    <#
    .SYNOPSIS
    Checks if any high-privilege first-party Microsoft service principals (e.g. Azure PowerShell, Azure CLI,
    Microsoft Graph Command Line Tools, Graph Explorer, Azure AD PowerShell, Exchange Online PowerShell,
    SharePoint Online Management Shell, Teams PowerShell, Power Platform CLI) are open to all users instead of
    requiring explicit assignment.

    .DESCRIPTION
    A small set of Microsoft first-party applications carry broad, pre-consented delegated permissions to Azure
    Resource Manager and Microsoft Graph and are commonly used to enumerate or exfiltrate tenant data once an
    attacker has a foothold on any single user account. Unlike third-party apps, these service principals are
    automatically provisioned in every tenant and easy to overlook when locking down 'Assignment required?'.

    .EXAMPLE
    Test-MtHighPrivilegeServicePrincipalsForAllUsers

    Returns true if none of the monitored high-privilege service principals can be used by any user.

    .LINK
    https://maester.dev/docs/commands/Test-MtHighPrivilegeServicePrincipalsForAllUsers
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple service principals.')]
    [OutputType([bool])]
    param(

    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose 'Test-MtHighPrivilegeServicePrincipalsForAllUsers: Checking high-privilege first-party service principals for open assignment'

    try {

        $highPrivilegeApps = @(
            [pscustomobject]@{ AppId = '1950a258-227b-4e31-a9cf-717495945fc2'; Name = 'Microsoft Azure PowerShell'; Reason = 'Holds Directory.AccessAsUser.All and Application.ReadWrite.All - full directory and Azure Resource Manager control.' }
            [pscustomobject]@{ AppId = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'; Name = 'Microsoft Azure CLI'; Reason = 'Holds Directory.AccessAsUser.All and Application.ReadWrite.All - full directory and Azure Resource Manager control.' }
            [pscustomobject]@{ AppId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'; Name = 'Microsoft Graph Command Line Tools'; Reason = 'Backs Connect-MgGraph and the Microsoft Graph CLI - can be consented with any Graph scope, including tenant-wide admin permissions.' }
            [pscustomobject]@{ AppId = 'de8bc8b5-d9f9-48b1-a8ad-b748da725064'; Name = 'Graph Explorer'; Reason = 'Browser-based, no install required - lowest-friction way to query Microsoft Graph with a signed-in user''s consented scopes.' }
            [pscustomobject]@{ AppId = '1b730954-1685-4b74-9bfd-dac224a7b894'; Name = 'Azure Active Directory PowerShell (legacy)'; Reason = 'Holds Directory.ReadWrite.All - full directory control via the deprecated AzureAD module.' }
            [pscustomobject]@{ AppId = '12128f48-ec9e-42f0-b203-ea49fb6af367'; Name = 'Microsoft Teams PowerShell Cmdlets'; Reason = 'Holds Group.ReadWrite.All and TeamSettings.ReadWrite.All - can modify any Team, channel, or Microsoft 365 group.' }
            [pscustomobject]@{ AppId = 'fb78d390-0c51-40cd-8e17-fdbfab77341b'; Name = 'Microsoft Exchange Online PowerShell'; Reason = 'Grants full Exchange Online admin impersonation - mailbox permissions, transport rules, connectors.' }
            [pscustomobject]@{ AppId = '9bc3ab49-b65d-410a-85ad-de819febfddc'; Name = 'Microsoft SharePoint Online Management Shell'; Reason = 'Grants full SharePoint Online tenant admin impersonation - site collections, sharing policy.' }
            [pscustomobject]@{ AppId = '9cee029c-6210-4654-90bb-17e6e9d36617'; Name = 'Power Platform CLI'; Reason = 'Holds Application.ReadWrite.All - can impersonate other app registrations to escalate privileges.' }
        )

        $appIdFilter = ($highPrivilegeApps.AppId | ForEach-Object { "appId eq '$_'" }) -join ' or '

        $params = @{
            'RelativeUri' = 'serviceprincipals'
            'Select'      = 'id,displayName,appId,appRoleAssignmentRequired,accountEnabled'
            'Filter'      = "($appIdFilter)"
        }

        $spns = Invoke-MtGraphRequest @params

        # No dedicated properties blade to deep-link to for apps that aren't provisioned in this tenant, so
        # fall back to Microsoft's own first-party app reference. The hover title still explains the risk either way.
        $referenceLink = 'https://learn.microsoft.com/en-us/troubleshoot/entra/entra-id/governance/verify-first-party-apps-sign-in'

        $appRows = foreach ($app in $highPrivilegeApps) {
            $spn = $spns | Where-Object { $_.appId -eq $app.AppId } | Select-Object -First 1

            if (-not $spn) {
                Write-Verbose "Test-MtHighPrivilegeServicePrincipalsForAllUsers: $($app.Name) ($($app.AppId)) is not provisioned in this tenant"
                [pscustomobject]@{
                    Name    = $app.Name
                    AppId   = $app.AppId
                    Status  = 'Not present in tenant'
                    IsOpen  = $false
                    SpnLink = $referenceLink
                    Reason  = $app.Reason
                }
            } else {
                $isOpen = $spn.accountEnabled -eq $true -and $spn.appRoleAssignmentRequired -ne $true
                Write-Verbose "Test-MtHighPrivilegeServicePrincipalsForAllUsers: $($spn.displayName) ($($spn.appId)) open to all users: $isOpen"
                [pscustomobject]@{
                    Name    = $spn.displayName
                    AppId   = $spn.appId
                    Status  = if ($isOpen) { 'Open to all users' } else { 'Assignment required' }
                    IsOpen  = $isOpen
                    SpnLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Properties/objectId/$($spn.id)/appId/$($spn.appId)"
                    Reason  = $app.Reason
                }
            }
        }

        $buildAppTable = {
            param($Rows)
            $table = "| Application | Application Id | Status |`n"
            $table += "| --- | --- | --- |`n"
            foreach ($row in $Rows) {
                $nameCell = "[$($row.Name)]($($row.SpnLink) `"$($row.Reason)`")"
                $table += "| $nameCell | $($row.AppId) | $($row.Status) |`n"
            }
            return $table
        }

        $openRows = $appRows | Where-Object { $_.IsOpen }
        $openCount = ($openRows | Measure-Object).Count
        $return = $openCount -eq 0

        if ($return) {
            $testResultMarkdown = "Well done. All monitored high-privilege first-party service principals present in this tenant require explicit user assignment.`n`n"
            $testResultMarkdown += & $buildAppTable $appRows
        } else {
            $otherRows = $appRows | Where-Object { -not $_.IsOpen }
            $testResultMarkdown = "You have $openCount high-privilege first-party service principals that can be used by any user.`n`n"
            $testResultMarkdown += "**Open to all users**`n`n"
            $testResultMarkdown += & $buildAppTable $openRows
            $testResultMarkdown += "`n**Other monitored apps**`n`n"
            $testResultMarkdown += & $buildAppTable $otherRows
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
