function Test-MtAsdSmartLockoutThreshold {
    <#
    .SYNOPSIS
    Checks that the Microsoft Entra smart lockout threshold is five failed sign-ins or fewer.

    .DESCRIPTION
    ISM-1403 (Guidelines for system access, User account lockouts) asks that user accounts, except for break
    glass accounts, are protected by fixed or risk-based lockout mechanisms aligned to a maximum of five failed
    logon attempts. This control is not part of the Essential Eight Maturity Model.

    Microsoft Entra smart lockout locks an account for the lockout duration after the configured number of
    failed sign-ins, and tracks familiar and unfamiliar locations separately. The check reads the tenant's
    Password Rule Settings and passes when the lockout threshold is explicitly set to the maximum given
    (5 by default) or fewer. The Microsoft default of 10 fails.

    .EXAMPLE
    Test-MtAsdSmartLockoutThreshold

    Returns true when the smart lockout threshold is 5 or fewer.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1403
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1403',
        Title = 'User accounts are protected by lockout mechanisms aligned to a maximum of five failed logon attempts.',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110',
        Control = ('ism:ISM-1403', 'nist-800-53-r5:AC-7'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The most failed sign-ins allowed before an account is locked.
        [ValidateRange(1, 50)]
        [int] $MaximumFailedAttempts = 5
    )

    $settings = Invoke-MtGraphRequest -RelativeUri 'settings' -ApiVersion beta
    $rawValue = $settings.values | Where-Object name -EQ 'LockoutThreshold' | Select-Object -First 1 -ExpandProperty value
    $isSet = -not [string]::IsNullOrWhiteSpace([string]$rawValue)
    $threshold = if ($isSet) { [int]$rawValue } else { 10 }
    $testResult = $isSet -and $threshold -le $MaximumFailedAttempts

    if ($testResult) {
        $testResultMarkdown = "Well done. The smart lockout threshold is **$threshold** failed sign-ins, which is $MaximumFailedAttempts or fewer."
    } elseif (-not $isSet) {
        $testResultMarkdown = "The smart lockout threshold is not set explicitly, so the Microsoft default of **10** failed sign-ins applies. Set it to **$MaximumFailedAttempts** or fewer."
    } else {
        $testResultMarkdown = "The smart lockout threshold is **$threshold** failed sign-ins. Set it to **$MaximumFailedAttempts** or fewer."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
