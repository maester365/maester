function Test-MtAdUserSpnDomainAdminDetails {
    <#
    .SYNOPSIS
    Provides detailed information about SPNs configured on domain administrator accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on domain
    administrator accounts and provides detailed information about each SPN.
    This includes the service class, host, and full SPN value for investigation.

    .EXAMPLE
    Test-MtAdUserSpnDomainAdminDetails

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes detailed information about domain admin SPNs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnDomainAdminDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
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

    # Extract detailed SPN information from domain admin accounts
    $adminSpnDetails = $domainAdmins | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $admin = $_
        $admin.servicePrincipalName | ForEach-Object {
            # Parse SPN to extract components
            if ($_ -match "^([^/]+)/([^:]+)(?::(\d+))?$") {
                $serviceClass = $matches[1]
                $hostPart = $matches[2]
                $port = $matches[3]

                [PSCustomObject]@{
                    SPN          = $_
                    ServiceClass = $serviceClass
                    Host         = $hostPart
                    Port         = $port
                    IsFqdn       = $hostPart -like "*.*"
                    AdminAccount = $admin.SamAccountName
                    AdminSID     = $admin.SID
                    Enabled      = $admin.Enabled
                }
            }
        }
    }

    $totalAdminSpns = ($adminSpnDetails | Measure-Object).Count
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

        if ($totalAdminSpns -gt 0) {
            $result += "`n**⚠️ Critical**: Domain administrator accounts have SPNs configured. These must be removed immediately.`n`n"
            $result += "### Domain Admin SPN Details`n`n"
            $result += "| Account | SPN | Service Class | Host | FQDN |`n"
            $result += "| --- | --- | --- | --- | --- |`n"

            foreach ($spnDetail in $adminSpnDetails) {
                $fqdnStatus = if ($spnDetail.IsFqdn) { "Yes" } else { "No" }
                $result += "| $($spnDetail.AdminAccount) | $($spnDetail.SPN) | $($spnDetail.ServiceClass) | $($spnDetail.Host) | $fqdnStatus |`n"
            }

            # Service class breakdown
            $serviceClassGroups = $adminSpnDetails | Group-Object ServiceClass | Sort-Object Count -Descending
            $result += "`n### Service Class Breakdown`n`n"
            $result += "| Service Class | Count |`n"
            $result += "| --- | --- |`n"
            foreach ($group in $serviceClassGroups) {
                $result += "| $($group.Name) | $($group.Count) |`n"
            }
        } else {
            $result += "`n**✅ Good**: No domain administrator accounts have SPNs configured.`n"
        }

        $testResultMarkdown = "Active Directory domain administrator SPN detailed analysis.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}





