function Get-MdeComplianceResultMarkdown {
    <#
    .SYNOPSIS
        Builds the result text for a Microsoft Defender Antivirus policy check

    .DESCRIPTION
        Turns the hashtable from Test-MdePolicyCompliance into the markdown the MDE antivirus checks
        (MT.1148 to MT.1171) show in the report: one sentence that matches the compliance logic and
        the outcome, followed by a table with each evaluated policy's result for the setting.

        Policies are called "assigned" when only assigned policies were evaluated (the default
        PolicyFiltering of OnlyAssigned) and "evaluated" otherwise, because PolicyFiltering All and
        IncludeUnassigned also read policies that reach no device.

    .PARAMETER Compliance
        The hashtable returned by Test-MdePolicyCompliance.

    .PARAMETER SettingName
        The setting as the start of a sentence, for example 'Archive scanning'.

    .PARAMETER ExpectedState
        What a compliant setting is, completing "<SettingName> is ...", for example 'enabled' or
        'correctly configured between 20-30%'.

    .EXAMPLE
        Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Archive scanning' -ExpectedState 'enabled'

        Returns the markdown for the archive scanning check.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Compliance,

        [Parameter(Mandatory = $true)]
        [string]$SettingName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedState
    )

    $total = $Compliance.TotalCount
    $compliantCount = @($Compliance.CompliantPolicies).Count
    $nonCompliantCount = @($Compliance.NonCompliantPolicies).Count
    $scope = if ($Compliance.PolicyFiltering -in 'All', 'IncludeUnassigned') { 'evaluated' } else { 'assigned' }

    # "the assigned Defender Antivirus policy" / "all 3 assigned Defender Antivirus policies", and so on.
    $thePolicies = if ($total -eq 1) { "the $scope Defender Antivirus policy" } else { "all $total $scope Defender Antivirus policies" }
    $anyPolicy = if ($total -eq 1) { "the $scope Defender Antivirus policy" } else { "any of the $total $scope Defender Antivirus policies" }

    if ($Compliance.IsCompliant -and $Compliance.ComplianceCheck -eq 'NotRequired') {
        $areCompliant = if ($total -eq 1) { 'is compliant' } else { 'are compliant' }
        $summary = "Well done. $SettingName is $ExpectedState, and $thePolicies $areCompliant."
    } elseif ($Compliance.IsCompliant -and $Compliance.ComplianceLogic -eq 'AnyPolicy') {
        $summary = "Well done. $SettingName is $ExpectedState in at least one $scope Defender Antivirus policy."
    } elseif ($Compliance.IsCompliant -and $compliantCount -eq $total) {
        $summary = "Well done. $SettingName is $ExpectedState in $thePolicies."
    } elseif ($Compliance.IsCompliant) {
        # EffectivePolicy with some policies that leave the setting unconfigured. Maester does not resolve
        # which devices each policy reaches, so say what was checked and what the admin must confirm.
        $setsIt = if ($compliantCount -eq 1) { 'the policy that sets it is' } else { 'the policies that set it are' }
        $summary = "Well done. $SettingName is $ExpectedState in $compliantCount of the $total $scope Defender Antivirus policies, " +
        "and no policy sets a different value; the others don't configure it. " +
        "Make sure $setsIt assigned to every device that needs this setting."
    } elseif ($Compliance.ComplianceLogic -eq 'EffectivePolicy' -and $Compliance.HasConflict) {
        $summary = "$SettingName is set to different values by the $scope Defender Antivirus policies. " +
        "Devices that receive only a policy with the other value are not compliant, and devices that receive both have a conflict " +
        "that Intune may resolve to either value. Use the compliant value in every policy that sets it."
    } elseif ($Compliance.ComplianceLogic -eq 'EffectivePolicy' -and $nonCompliantCount -gt 0) {
        $usesIt = if ($nonCompliantCount -eq 1) { "the $scope policy that sets it uses" } else { "the $scope policies that set it use" }
        $summary = "$SettingName is not ${ExpectedState}: $usesIt a different value."
    } elseif ($Compliance.ComplianceLogic -eq 'EffectivePolicy') {
        $summary = "$SettingName isn't set in $anyPolicy, so Maester can't confirm it. Set it in a policy assigned to your devices."
    } elseif ($Compliance.ComplianceLogic -eq 'AnyPolicy') {
        $summary = "$SettingName is not $ExpectedState in any $scope Defender Antivirus policy."
    } else {
        $summary = "$SettingName is not properly configured in all policies."
    }

    $rows = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @($Compliance.CompliantPolicies)) { $rows.Add("| $(Get-MtSafeMarkdown $name) | ✅ Compliant |") }
    foreach ($name in @($Compliance.NonCompliantPolicies)) { $rows.Add("| $(Get-MtSafeMarkdown $name) | ❌ Different value |") }
    foreach ($name in @($Compliance.NotConfiguredPolicies)) {
        $status = if ($Compliance.ComplianceLogic -eq 'AllPolicies') { '❌ Not configured' } else { '➖ Not configured' }
        $rows.Add("| $(Get-MtSafeMarkdown $name) | $status |")
    }

    if ($rows.Count -eq 0) {
        return $summary
    }

    $table = "| Policy | Setting |`n| --- | --- |`n" + ($rows -join "`n")
    return "$summary`n`n$table"
}
