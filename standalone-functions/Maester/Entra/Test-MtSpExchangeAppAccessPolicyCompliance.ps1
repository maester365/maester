function Test-MtSpExchangeAppAccessPolicyCompliance {
    <#
    .SYNOPSIS
    Check if service principals with Exchange permissions have application access policies configured.

    .DESCRIPTION
    Service principals with Exchange permissions can access all mailboxes by default. This test verifies that proper access policies are in place.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtSpExchangeAppAccessPolicyCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose 'Running Test-MtSpExchangeAppAccessPolicy'


    try {
        # Note: If you make any changes to this list, please keep it in sync
        # with the markdown file Test-MtSpExchangeAppAccessPolicy.md
        $exchangePermissions = @(
            'Mail.Read', 'Mail.ReadBasic', 'Mail.ReadBasic.All', 'Mail.ReadWrite', 'Mail.Send',
            'MailboxSettings.Read', 'MailboxSettings.ReadWrite',
            'Calendars.Read', 'Calendars.ReadWrite',
            'Contacts.Read', 'Contacts.ReadWrite'
        )

        # Get service principals with Exchange permissions
        $msGraph = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
        $availablePermissions = $msGraph.AppRoles | Select-Object Id, Value

        $servicePrincipals = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals'
        $principalsWithExchangePerms = $servicePrincipals | ForEach-Object {
            $sp = $_
            $appRoles = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/appRoleAssignments'
            $permissions = $appRoles.AppRoleId | ForEach-Object {
                $roleId = $_
                ($availablePermissions | Where-Object { $_.Id -eq $roleId }).Value
            }

            if ($permissions | Where-Object { $_ -in $exchangePermissions }) {
                [PSCustomObject]@{
                    Id          = $sp.Id
                    DisplayName = $sp.DisplayName
                    AppId       = $sp.AppId
                    Permissions = $permissions -join ', '
                }
            }
        }

        # Get application access policies
        try {
            $appAccessPolicies = Get-ApplicationAccessPolicy -ErrorAction Stop
        } catch {
            if ($_.Exception.Message -like "*couldn't be found*") {
                Write-Verbose -Message 'Test-MtSpExchangeAppAccessPolicy: No application access policies were found.'
                $appAccessPolicies = $null
            } else {
                throw
            }
        }

        $missingPolicies = @()
        $appsWithPolicies = @()
        foreach ($sp in $principalsWithExchangePerms) {
            $hasPolicy = $appAccessPolicies.AppId -contains $sp.AppId
            $filteredPermissions = $sp.Permissions -split ', ' | Where-Object { $_ -in $exchangePermissions }
            $appRecord = [PSCustomObject]@{
                Id          = $sp.Id
                DisplayName = $sp.DisplayName
                AppId       = $sp.AppId
                Permissions = $filteredPermissions -join ', '
            }

            if (-not $hasPolicy) {
                $missingPolicies += $appRecord
            } else {
                $appsWithPolicies += $appRecord
            }
        }

        $appsWithExchangePermissionsCount = ($principalsWithExchangePerms | Measure-Object).Count
        $invalidCount = ($missingPolicies | Measure-Object).Count
        $result = $invalidCount -eq 0

        if ($appsWithExchangePermissionsCount -eq 0) {
        } elseif ($result) {
        } else {

            $missingPoliciesMarkdown = "`n`n### Applications Missing Exchange Application Access Policies`n`n"
            $missingPoliciesMarkdown += "| Application | Application ID | Exchange Permissions |`n"
            $missingPoliciesMarkdown += "| --- | --- | --- |`n"

            foreach ($app in ($missingPolicies | Sort-Object -Property DisplayName)) {
            }

        }

        if ($appsWithPolicies.Count -gt 0 -and $invalidCount -gt 0) {
        }

        return $result
    } catch {
        return $null
    }

}
