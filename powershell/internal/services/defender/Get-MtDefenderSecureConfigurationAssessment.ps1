function Get-MtDefenderSecureConfigurationAssessment {
    <#
    .SYNOPSIS
    Returns one row per Defender Vulnerability Management security configuration, with how many devices
    it applies to and how many of those are not compliant with it.

    .DESCRIPTION
    Runs a single advanced hunting query over DeviceTvmSecureConfigurationAssessment, joined to
    DeviceTvmSecureConfigurationAssessmentKB for the configuration's name, description, risk and impact.
    The aggregation happens server side, so the result is one row per configuration rather than one row
    per device and configuration.

    Only configurations Defender reports as applicable to at least one device are returned. A
    configuration that applies to nothing cannot be complied with or breached, so it has no outcome to
    judge.

    An empty result means Defender Vulnerability Management has no assessment data for this tenant,
    typically because no device is onboarded to Defender for Endpoint. The caller must skip in that case:
    "no configuration is non-compliant" over zero assessed configurations is not a pass.

    Errors are deliberately not caught here. Invoke-MtGraphSecurityQuery throws on a query execution
    error, and letting that surface keeps a broken query from being reported as a clean tenant.

    .EXAMPLE
    Get-MtDefenderSecureConfigurationAssessment

    Returns the security configurations assessed in the tenant with their non-compliant device counts.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    # Aggregated server side: one row per configuration. make_set_if is capped so a configuration that
    # is non-compliant on thousands of devices does not drag the whole result set back.
    $query = @'
DeviceTvmSecureConfigurationAssessment
| where IsApplicable == true
| summarize ApplicableDeviceCount = dcount(DeviceId),
            NonCompliantDeviceCount = dcountif(DeviceId, IsCompliant == false),
            NonCompliantDeviceList = make_set_if(DeviceName, IsCompliant == false, 10),
            ConfigurationCategory = any(ConfigurationCategory),
            ConfigurationSubcategory = any(ConfigurationSubcategory)
    by ConfigurationId
| join kind=leftouter (
    DeviceTvmSecureConfigurationAssessmentKB
    | project ConfigurationId, ConfigurationName, ConfigurationDescription, RiskDescription, ConfigurationImpact
  ) on ConfigurationId
| project-away ConfigurationId1
| sort by NonCompliantDeviceCount desc, ConfigurationImpact desc
'@

    Write-Verbose 'Querying Defender Vulnerability Management secure configuration assessment...'
    $rows = @(Invoke-MtGraphSecurityQuery -Query $query -Timespan 'P1D')

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $rows) {
        if (-not $row -or [string]::IsNullOrWhiteSpace([string]$row.ConfigurationId)) { continue }
        $result.Add([pscustomobject]@{
                ConfigurationId          = [string]$row.ConfigurationId
                Name                     = [string]$row.ConfigurationName
                Description              = [string]$row.ConfigurationDescription
                RiskDescription          = [string]$row.RiskDescription
                Category                 = [string]$row.ConfigurationCategory
                Subcategory              = [string]$row.ConfigurationSubcategory
                # $null, not 0, when the knowledge base has no row for this configuration: the join
                # above is a leftouter, and [double]$null is 0, which reads as "impact 1 to 10, the
                # lowest" rather than "not known". The caller decides what to do with the absence.
                Impact                   = if ($null -eq $row.ConfigurationImpact -or [string]::IsNullOrWhiteSpace([string]$row.ConfigurationImpact)) { $null } else { [double]$row.ConfigurationImpact }
                ApplicableDeviceCount    = [int]($row.ApplicableDeviceCount)
                NonCompliantDeviceCount  = [int]($row.NonCompliantDeviceCount)
                NonCompliantDeviceList   = @($row.NonCompliantDeviceList)
            })
    }

    # -NoEnumerate keeps an empty list from collapsing to $null, so the caller can tell an empty
    # assessment from a list it can iterate.
    Write-Output $result -NoEnumerate
}
