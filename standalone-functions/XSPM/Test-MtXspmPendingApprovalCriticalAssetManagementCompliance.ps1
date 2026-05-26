function Test-MtXspmPendingApprovalCriticalAssetManagementCompliance {
    <#
    .SYNOPSIS
    Tests for pending approval for Critical Asset Management.

    .DESCRIPTION
    Tests for pending approval for Critical Asset Management.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmPendingApprovalCriticalAssetManagementCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation
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
    } else {

        Write-Verbose "Found $($PendingApprovals.Count) pending approvals for Critical Asset Management in total."

        $result = "| Classification | Pending Approvals | Affected Assets | `n"
        $result += "| --- | --- | --- |`n"
        foreach ($PendingApproval in $PendingApprovals) {
            $Assets = $($PendingApproval.Assets) -join ', '   # "host1, host2, host3"
            $result += "| $($PendingApproval.Classification) | $($PendingApproval.PendingApproval) | $($Assets) |`n"
        }
    }
    $result = [string]::IsNullOrEmpty($PendingApprovals)
    return $result

}
