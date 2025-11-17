<#
.SYNOPSIS
    Tests for pending approval for Critical Asset Management.

.DESCRIPTION
    Tests for pending approval for Critical Asset Management.

.OUTPUTS
    [bool] - Returns $true if no pending approvals for Critical Asset Management are found, $false if any are found, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmPendingApprovalCriticalAssetManagement

.LINK
    https://maester.dev/docs/commands/Test-MtXspmPendingApprovalCriticalAssetManagement
#>

function Test-MtXspmPendingApprovalCriticalAssetManagement {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks for pending approvals for Critical Asset Management.')]
    [OutputType([bool])]
    param()

    Write-Verbose "Get raw data from ExposureGraphNodes..."
    $Query = "
        ExposureGraphNodes
        | where isnotempty(parse_json(NodeProperties)['rawData']['criticalityConfidenceLow'])
        | mv-expand parse_json(NodeProperties)['rawData']['criticalityConfidenceLow']
        | extend Classification = tostring(NodeProperties_rawData_criticalityConfidenceLow)
        | summarize PendingApproval = count(), Assets = array_sort_asc(make_set(NodeName)) by Classification
        | sort by Classification asc
    "
    $PendingApprovals = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P1D"

    $Severity = "Medium"

    if ($return -or [string]::IsNullOrEmpty($PendingApprovals)) {
        $testResultMarkdown = "Well done. No pending approvals for Critical Asset Management are found."
    } else {
        $testResultMarkdown = "At least one approval is pending for Critical Asset Management.`n`n%TestResult%"

        Write-Verbose "Found $($PendingApprovals.Count) pending approvals for Critical Asset Management in total."

        $result = "| Classification | Pending Approvals | Affected Assets | `n"
        $result += "| --- | --- | --- |`n"
        foreach ($PendingApproval in $PendingApprovals) {
            $Assets = $($PendingApproval.Assets) -join ', '   # "host1, host2, host3"
            $result += "| $($PendingApproval.Classification) | $($PendingApproval.PendingApproval) | $($Assets) |`n"
        }
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity
    $result = [string]::IsNullOrEmpty($PendingApprovals)
    return $result
}