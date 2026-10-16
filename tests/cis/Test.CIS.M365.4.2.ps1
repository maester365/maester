function Test-MtCisPersonalDeviceEnrollmentBlocked {
    <#
    .SYNOPSIS
        Checks that the default Intune platform restriction blocks personal device enrollment on every platform.

    .DESCRIPTION
        Checks that the default Microsoft Intune device platform restriction either blocks the platform or blocks personally owned devices for Windows, iOS/iPadOS, macOS, Android Enterprise and Android device administrator.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (4.2, L1)

    .EXAMPLE
        Test-MtCisPersonalDeviceEnrollmentBlocked

        Returns true if the default enrollment restriction blocks personal devices on all platforms.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.4.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.4.2',
        Title = 'Ensure device enrollment for personally owned devices is blocked by default',
        Product = 'intune',
        Feature = 'device-enrollment',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('cis-m365:4.2', 'nist-800-53-r5:AC-19'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the device enrollment configurations...'
    $configurations = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/deviceEnrollmentConfigurations' -ApiVersion beta -DisableCache
    $default = @($configurations) | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.deviceEnrollmentPlatformRestrictionsConfiguration' -and $_.id -like '*_DefaultPlatformRestrictions' } | Select-Object -First 1

    $platforms = [ordered]@{
        'Windows' = $default.windowsRestriction
        'iOS/iPadOS' = $default.iosRestriction
        'macOS' = $default.macOSRestriction
        'Android Enterprise (work profile)' = $default.androidForWorkRestriction
        'Android device administrator' = $default.androidRestriction
    }
    $checks = foreach ($platform in $platforms.Keys) {
        $restriction = $platforms[$platform]
        $value = if ($null -eq $restriction) { 'Not found' } elseif ($restriction.platformBlocked -eq $true) { 'Platform blocked' } elseif ($restriction.personalDeviceEnrollmentBlocked -eq $true) { 'Personal devices blocked' } else { 'Personal devices allowed' }
        [pscustomobject]@{ Setting = $platform; Value = $value; Pass = $restriction.platformBlocked -eq $true -or $restriction.personalDeviceEnrollmentBlocked -eq $true }
    }
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The default enrollment restriction blocks personally owned devices on every platform.'
    $failText = 'The default enrollment restriction allows personally owned devices on at least one platform.'
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
