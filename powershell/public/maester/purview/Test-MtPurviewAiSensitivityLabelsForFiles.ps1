function Test-MtPurviewAiSensitivityLabelsForFiles {
    <#
    .SYNOPSIS
    Ensure Microsoft Purview sensitivity labels are published so Microsoft 365 Copilot and DSPM for AI honor and inherit them on AI-generated content.

    .DESCRIPTION
    Checks that at least one sensitivity label policy is published, and that at least one published label is
    scoped to files (the scope that governs SharePoint, OneDrive and Office files used by Microsoft 365 Copilot).

    Microsoft 365 Copilot only respects sensitivity labels and inherits the most restrictive label onto generated
    content if labels are actually published to users. When no label is published or no published label targets
    files, Copilot has no labelling signal to apply and DSPM for AI cannot report on label-based oversharing.

    The test passes if at least one published label policy exists AND at least one label has the File scope.

    .EXAMPLE
    Test-MtPurviewAiSensitivityLabelsForFiles

    Returns true if a sensitivity label scoped to files is published in the tenant.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAiSensitivityLabelsForFiles
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Files is the Microsoft Purview sensitivity label scope being tested')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    try {
        $labels = Get-Label -ErrorAction Stop
        $labelPolicies = Get-LabelPolicy -ErrorAction Stop

        $publishedPolicies = @($labelPolicies | Where-Object { $_.Mode -eq 'Enforce' -or $_.Enabled })
        # ContentType is a multi-valued field including 'File', 'Email', 'Site', 'UnifiedGroup', 'PurviewAssets' etc.
        $fileLabels = @($labels | Where-Object { $_.ContentType -match 'File' })

        $hasPublishedPolicy = $publishedPolicies.Count -ge 1
        $hasFileLabel = $fileLabels.Count -ge 1
        $testResult = $hasPublishedPolicy -and $hasFileLabel

        $portalLink = "https://purview.microsoft.com/informationprotection/labels"

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant publishes [sensitivity labels]($portalLink) scoped to files, "
            $testResultMarkdown += "so Microsoft 365 Copilot honors and inherits them on AI-generated content.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant does not have [sensitivity labels]($portalLink) published for files.`n`n"
            $testResultMarkdown += "> **Risk:** Microsoft 365 Copilot cannot honor or inherit sensitivity labels onto AI-generated content "
            $testResultMarkdown += "if no published label targets files. DSPM for AI oversharing reports based on labels will also be empty.`n`n%TestResult%"
        }

        $passResult = "✅ Pass"
        $failResult = "❌ Fail"
        $result = "| Check | Status | Details |`n"
        $result += "| --- | --- | --- |`n"
        $result += "| Published label policy exists | $(if ($hasPublishedPolicy) { $passResult } else { $failResult }) | $($publishedPolicies.Count) policy(ies) published |`n"
        $result += "| Label with File scope exists | $(if ($hasFileLabel) { $passResult } else { $failResult }) | $($fileLabels.Count) label(s) scoped to files |`n"

        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
