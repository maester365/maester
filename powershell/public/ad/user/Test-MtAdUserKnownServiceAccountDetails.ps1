function Test-MtAdUserKnownServiceAccountDetails {
    <#
    .SYNOPSIS
    Returns details for users matching known service account naming patterns.

    .DESCRIPTION
    This test identifies user accounts that look like service accounts based on
    commonly used naming conventions. Service accounts often receive elevated
    permissions, non-expiring passwords, or SPNs, so maintaining visibility into
    them is important for Active Directory hygiene and security reviews.

    .EXAMPLE
    Test-MtAdUserKnownServiceAccountDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserKnownServiceAccountDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserKnownServiceAccountDetails"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user known service account details"

    $users = $adState.Users

    $serviceAccountPatterns = @(
        @{ Name = 'svc-prefix'; Regex = '^(svc|service)[-_.]' },
        @{ Name = 'svc-suffix'; Regex = '[-_.](svc|service)$' },
        @{ Name = 'application-prefix'; Regex = '^(app|web|api|batch|job|task)[-_.]' },
        @{ Name = 'sql-prefix'; Regex = '^(sql|db)[-_.]' },
        @{ Name = 'admin-service'; Regex = '^(adm|admin)[-_.](svc|service)' },
        @{ Name = 'sa-prefix'; Regex = '^sa[-_.]' }
    )

    $serviceAccounts = foreach ($user in $users) {
        $candidateValues = @($user.SamAccountName, $user.Name) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $matchedPattern = $null

        foreach ($pattern in $serviceAccountPatterns) {
            if ($candidateValues | Where-Object { $_ -match $pattern.Regex }) {
                $matchedPattern = $pattern.Name
                break
            }
        }

        if ($null -ne $matchedPattern) {
            [PSCustomObject]@{
                SamAccountName       = $user.SamAccountName
                Name                 = $user.Name
                Enabled              = $user.Enabled
                PatternMatched       = $matchedPattern
                PasswordNeverExpires = $user.PasswordNeverExpires
                HasSpn               = @($user.ServicePrincipalName).Count -gt 0
                DistinguishedName    = $user.DistinguishedName
            }
        }
    }

    $serviceAccounts = @($serviceAccounts | Sort-Object SamAccountName -Unique)
    $serviceAccountCount = ($serviceAccounts | Measure-Object).Count
    $enabledCount = (@($serviceAccounts | Where-Object { $_.Enabled -eq $true }) | Measure-Object).Count
    $passwordNeverExpiresCount = (@($serviceAccounts | Where-Object { $_.PasswordNeverExpires -eq $true }) | Measure-Object).Count
    $hasSpnCount = (@($serviceAccounts | Where-Object { $_.HasSpn -eq $true }) | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Users Reviewed | $((@($users) | Measure-Object).Count) |`n"
    $result += "| Matching Service Account Patterns | $serviceAccountCount |`n"
    $result += "| Enabled Matches | $enabledCount |`n"
    $result += "| Password Never Expires | $passwordNeverExpiresCount |`n"
    $result += "| Matches with SPNs | $hasSpnCount |`n`n"

    if ($serviceAccountCount -gt 0) {
        $result += "### Matching User Accounts`n`n"
        $result += "| SamAccountName | Display Name | Enabled | Pattern | Password Never Expires | Has SPN |`n"
        $result += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($account in ($serviceAccounts | Select-Object -First 25)) {
            $result += "| $($account.SamAccountName) | $($account.Name) | $($account.Enabled) | $($account.PatternMatched) | $($account.PasswordNeverExpires) | $($account.HasSpn) |`n"
        }

        if ($serviceAccountCount -gt 25) {
            $result += "| ... | ... | ... | ... | ... | ... ($($serviceAccountCount - 25) more) |`n"
        }
    } else {
        $result += "No users matched the configured service account naming patterns.`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory users were reviewed for known service account naming patterns.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserKnownServiceAccountDetails"

    return $testResult
}


