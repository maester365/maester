BeforeDiscovery {
    try {
        $OAuthAppDetails = (Get-MtOAuthAppDetailsFromXdr).results
        Write-Verbose "Found $($OAuthAppDetails.Count) application or workload identities"
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
    }
}

Describe "Application Management - No ownership on sensitive apps" -Tag "Maester", "Privileged", "Security", "All" {
    It "MT.1057: Ownership on apps with sensitive API permissions. See https://maester.dev/docs/tests/MT.1057" -Tag "MT.1057" {

        $AppsWithOwners = $OAuthAppDetails | Where-Object { $null -ne $_.OwnedBy }
        $SensitiveApiRolesOnAppsWithOwners = $AppsWithOwners | Where-Object {$_.ApiPermissions -match '"EAMTierLevelName":"ControlPlane"' -or $_.ApiPermissions -match '"PrivilegeLevel":"High"'}

        if ($return) {
            $testResultMarkdown = "Well done. No application and workload identity has a high privilege API permission with an owner."
        } else {
            $testResultMarkdown = "At least one application has API permissions with a risk of sensitive API permissions.`n`n%TestResult%"

            $result = "| ApplicationName | ApplicationId | Ownership | Sensitive App Role | API Provider |`n"
            $result += "| --- | --- | --- | --- | --- |`n"
            foreach ($SensitiveApp in $SensitiveApiRolesOnAppsWithOwners) {
                $filteredApiPermissions = $SensitiveApp.ApiPermissions | ConvertFrom-Json -Depth 10 | Where-Object { $_.EAMTierLevelName -eq "ControlPlane" -or $_.PrivilegeLevel -eq "High" } | Select-Object AppDisplayName, AppRoleDisplayName
                $SensitiveApp.OwnedBy | ConvertFrom-Json | ForEach-Object {
                    $result += "| $($SensitiveApp.ServicePrincipalName) | $($SensitiveApp.OAuthAppId) | $($_.NodeName) - $($_.NodeLabel) | $($filteredApiPermissions.AppRoleDisplayName) | $($filteredApiPermissions.AppDisplayName) |`n"
                }
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        #endregion
        # Actual test
        $SensitiveApiRolesOnAppsWithOwners.Count -eq "0" | Should -Be $True -Because $benefits
    }
}