function Test-MtDisaSignInBanner {
    <#
    .SYNOPSIS
    Checks that the Microsoft Entra sign-in page shows the Standard Mandatory DoD Notice and Consent Banner.

    .DESCRIPTION
    The DISA Microsoft Entra ID STIG (V-270209) asks that the Standard Mandatory DoD Notice and Consent Banner is
    displayed before access is granted. Its check reads the "Sign-in page text" of the default company branding
    and is a finding when the banner text is not there.

    This check reads the sign-in page text of the default company branding (organizationalBranding,
    signInPageText) and passes when it contains one of the given texts. By default it looks for the opening
    sentence of the full banner and for the short banner that DoD allows where space is limited; the field holds
    1,024 characters at most. Comparison ignores case and runs of white space.

    The banner is a DoD requirement, so this test is meant for DoD tenants.

    .EXAMPLE
    Test-MtDisaSignInBanner

    Returns true when the sign-in page text contains the DoD banner.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270209
    #>
    [MaesterTest(
        Id = 'DISA.V-270209',
        Title = 'Microsoft Entra ID must display the Standard Mandatory DoD Notice and Consent Banner before granting access to the application.',
        Product = 'entra',
        Feature = 'user-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = 'disa-stig-entra-id:V-270209',
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Texts of which the sign-in page text must contain one. Empty looks for the full and the short DoD banner.
        [string[]] $RequiredText
    )

    if (-not $RequiredText) {
        $RequiredText = @(
            'You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only.'
            "I've read & consent to terms in IS user agreem't."
        )
    }

    $normalize = { param([string] $Text) ($Text -replace '\s+', ' ').Trim() }
    $organization = @(Invoke-MtGraphRequest -RelativeUri 'organization')[0]
    $branding = $null
    try {
        $branding = Invoke-MtGraphRequest -RelativeUri "organization/$($organization.id)/branding"
    } catch {
        # A tenant without company branding answers 404.
        if ("$_" -notmatch 'NotFound|404') { throw }
    }
    $pageText = "$($branding.signInPageText)"
    $normalizedPage = & $normalize $pageText
    $found = @($RequiredText | Where-Object { $_ -and $normalizedPage.IndexOf((& $normalize $_), [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
    $testResult = $found.Count -gt 0

    $link = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyBrandingMenuBlade/~/CompanyBranding'
    if ($testResult) {
        $testResultMarkdown = "Well done. The sign-in page text of the [company branding]($link) shows the DoD Notice and Consent Banner."
    } elseif (-not $branding) {
        $testResultMarkdown = "The tenant has no [company branding]($link), so the sign-in page shows no banner. Customize the default branding and put the DoD banner in the sign-in page text."
    } elseif (-not $pageText) {
        $testResultMarkdown = "The [company branding]($link) has no sign-in page text. Put the DoD Notice and Consent Banner there."
    } else {
        $testResultMarkdown = "The sign-in page text of the [company branding]($link) does not contain the DoD Notice and Consent Banner. It reads:`n`n> $(Get-MtSafeMarkdown $normalizedPage)"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
