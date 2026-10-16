function Test-MtAdPasswordComplexityRequired {
    <#
    .SYNOPSIS
    Checks that password complexity is enabled in the default domain password policy.

    .DESCRIPTION
    This test retrieves the password complexity setting from the default domain password policy.
    Password complexity requires that passwords contain characters from three of the following
    categories: uppercase letters, lowercase letters, numbers, and special characters. This
    requirement helps prevent the use of common, easily guessable passwords.

    .EXAMPLE
    Test-MtAdPasswordComplexityRequired

    Returns $true if password complexity is enabled, $false if it is disabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdPasswordComplexityRequired
    #>
    [MaesterTest(
        Id = 'AD-PWDPOL-04',
        Title = 'Password complexity should be enabled',
        Product = 'ad',
        Feature = 'password-policy',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdPasswordComplexityRequired"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Domain')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    # Get the default domain password policy
    $passwordPolicy = $adState.Domain
    if ($null -eq $passwordPolicy -or $null -eq $passwordPolicy.PwdProperties) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    $complexityEnabled = ($passwordPolicy.PwdProperties -band 1) -ne 0

    # Test passes when password complexity is enabled
    $testResult = $complexityEnabled

    # Generate markdown results
    $complexityStatus = if ($complexityEnabled) { "Enabled" } else { "Disabled" }

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Password Complexity | $complexityStatus |" + "`n"
    $result += "| Recommended Setting | Enabled |" + "`n"

    $recommendation = if ($complexityEnabled) {
        "✅ Password complexity is enabled. This helps prevent the use of common, easily guessable passwords."
    } else {
        "⚠️ Password complexity is disabled. This allows users to create simple passwords that are vulnerable to brute-force and dictionary attacks. Enable complexity requirements."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
