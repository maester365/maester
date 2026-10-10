function Test-MtCisaAppGroupOwnerConsent {
    <#
    .SYNOPSIS
    Checks if group owners can consent to apps

    .DESCRIPTION
    Group owners SHALL NOT be allowed to consent to applications.

    .EXAMPLE
    Test-MtCisaAppGroupOwnerConsent

    Returns true if disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAppGroupOwnerConsent
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.5.4',
        Title = 'Group owners SHALL NOT be allowed to consent to applications.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Entra ID',
        Tag = ('Deprecated', 'Entra ID Free', 'MS.AAD', 'MS.AAD.5.4'),
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = ('michaelmsonne', 'weyCC81', 'SamErde')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA as of March 2025 (MS.AAD.5.4v1)."
    return $null
}
