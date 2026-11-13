function Test-MtCisaDlpLocationCoverage {
    <#
    .SYNOPSIS
    Checks whether sensitive-information DLP policies cover all required workloads.

    .DESCRIPTION
    A DLP policy protecting credit card numbers, ITINs, and SSNs SHOULD cover Exchange, OneDrive, SharePoint, Teams, and Devices.

    .EXAMPLE
    Test-MtCisaDlpLocationCoverage

    Returns true when enabled policies with non-disabled full-protection rules cover every required workload and location.

    .LINK
    https://maester.dev/docs/tests/CISA.MS.SECURITYSUITE.3.2
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.3.2',
        Title = 'The DLP policy SHOULD be applied to Exchange, OneDrive, SharePoint, Teams chat, and Devices.',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1567', 'T1530', 'T1213.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.3.2',
        Service = 'SecurityCompliance',
        License = 'EXCHANGE_DLP',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $fullProtectionRules = @(Get-MtCisaSensitiveDlpRule | Where-Object { $_.SensitiveTypes.Count -eq 3 })
    $locations = @(
        [pscustomobject]@{ Name = 'Exchange'; Workload = 'Exchange'; Property = 'ExchangeLocation' }
        [pscustomobject]@{ Name = 'OneDrive'; Workload = 'OneDriveForBusiness'; Property = 'OneDriveLocation' }
        [pscustomobject]@{ Name = 'SharePoint'; Workload = 'SharePoint'; Property = 'SharePointLocation' }
        [pscustomobject]@{ Name = 'Teams'; Workload = 'Teams'; Property = 'TeamsLocation' }
        [pscustomobject]@{ Name = 'Devices'; Workload = 'EndpointDevices'; Property = 'EndpointDlpLocation' }
    )

    $locationResults = foreach ($location in $locations) {
        $coveredRules = @(
            $fullProtectionRules | Where-Object {
                $policy = $_.Policy
                $workloads = @($policy.Workload | ForEach-Object { ([string]$_ -split ',') | ForEach-Object { $_.Trim() } })
                $locationValues = @(
                    $policy.($location.Property) | ForEach-Object {
                        if ($_ -is [string]) {
                            $_
                        } elseif ($_.DisplayName) {
                            $_.DisplayName
                        } elseif ($_.ImmutableIdentity) {
                            $_.ImmutableIdentity
                        } elseif ($_.Name) {
                            $_.Name
                        }
                    }
                )
                $workloads -contains $location.Workload -and $locationValues -contains 'All'
            }
        )
        [pscustomobject]@{
            Location = $location.Name
            Policies = @($coveredRules | ForEach-Object { $_.Policy.Identity } | Select-Object -Unique)
            Covered  = $coveredRules.Count -gt 0
        }
    }

    $testResult = @($locationResults | Where-Object { -not $_.Covered }).Count -eq 0
    $result = "| Workload | Enabled full-protection policy covering all locations | Result |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($locationResult in $locationResults) {
        $status = if ($locationResult.Covered) { '✅ Pass' } else { '❌ Fail' }
        $policyNames = if ($locationResult.Policies.Count -gt 0) { $locationResult.Policies -join ', ' } else { 'None' }
        $result += "| $($locationResult.Location) | $policyNames | $status |`n"
    }

    if ($testResult) {
        $message = "Well done. Enabled DLP policies with non-disabled rules protecting all required sensitive information types cover Exchange, OneDrive, SharePoint, Teams, and Devices.`n`n%TestResult%"
    } else {
        $message = "Enable DLP policies with non-disabled rules protecting credit card numbers, ITINs, and SSNs for all required Microsoft 365 and device locations.`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
