function Test-MtCisaAppAdminConsent {
    <#
    .SYNOPSIS
    Checks if admin consent workflow is configured with reviewers

    .DESCRIPTION
    An admin consent workflow SHALL be configured for applications.

    .EXAMPLE
    Test-MtCisaAppAdminConsent

    Returns true if configured

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAppAdminConsent
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.5.3',
        Title = 'An admin consent workflow SHALL be configured for applications.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Entra ID',
        Tag = ('Entra ID Free', 'MS.AAD', 'MS.AAD.5.3'),
        Service = 'Graph',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion v1.0

    $reviewers = $result | Where-Object {`
        $_.isEnabled -and `
        $_.notifyReviewers -and `
        $_.reviewers.Count -ge 1 } | Select-Object -ExpandProperty reviewers

    $testResult = ($reviewers|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant admin consent request policy has at least 1 reviewer."
    } else {
        $testResultMarkdown = "Your tenant admin consent request policy is not configured."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
