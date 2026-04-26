function Test-MtAdUserSpnDomainAdminCount {
    <#
    .SYNOPSIS
    Counts SPNs configured on domain administrator accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on domain
    administrator accounts. Domain admin accounts with SPNs are extremely high-risk
    targets for Kerberoasting attacks as they typically have the highest privileges.

    .EXAMPLE
    Test-MtAdUserSpnDomainAdminCount

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of SPNs on domain admin accounts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnDomainAdminCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $users = $adState.Users
    $domain = $adState.Domain

    # Get domain admin SID (RID 500 is the built-in Administrator)
    $domainAdminSid = "*$($domain.DomainSID.Value)-500"

    # Find domain admin accounts (built-in admin and users with RID 500 pattern)
    $domainAdmins = $users | Where-Object {
        $_.SID -like $domainAdminSid -or
        $_.SID -like "S-1-5-*-500"
    }

    # Extract SPNs from domain admin accounts
    $adminSpns = $domainAdmins | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $admin = $_
        $admin.servicePrincipalName | ForEach-Object {
            [PSCustomObject]@{
                SPN = $_
                AdminAccount = $admin.SamAccountName
                AdminSID = $admin.SID
            }
        }
    }

    $totalAdminSpns = ($adminSpns | Measure-Object).Count
    $adminsWithSpns = ($domainAdmins | Where-Object { $null -ne $_.servicePrincipalName } | Measure-Object).Count
    $totalDomainAdmins = ($domainAdmins | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Domain Admin Accounts | $totalDomainAdmins |`n"
        $result += "| Domain Admins with SPNs | $adminsWithSpns |`n"
        $result += "| Total SPNs on Domain Admins | $totalAdminSpns |`n"

        if ($totalDomainAdmins -gt 0) {
            $percentage = [Math]::Round(($adminsWithSpns / $totalDomainAdmins) * 100, 2)
            $result += "| Percentage with SPNs | $percentage% |`n"
        }

        if ($totalAdminSpns -gt 0) {
            $result += "`n**⚠️ Warning**: Domain administrator accounts have SPNs configured. This is a critical security risk for Kerberoasting attacks.`n`n"
            $result += "### Domain Admin Accounts with SPNs`n`n"
            $result += "| Account | SPN Count |`n"
            $result += "| --- | --- |`n"

            $adminGroups = $adminSpns | Group-Object AdminAccount
            foreach ($group in $adminGroups) {
                $result += "| $($group.Name) | $($group.Count) |`n"
            }
        } else {
            $result += "`n**✅ Good**: No domain administrator accounts have SPNs configured.`n"
        }

        $testResultMarkdown = "Active Directory domain administrator SPN analysis.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



