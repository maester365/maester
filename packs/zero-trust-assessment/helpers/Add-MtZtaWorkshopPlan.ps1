function Add-MtZtaWorkshopPlan {
    <#
    .SYNOPSIS
    Adds the Microsoft Zero Trust Workshop plan to the Maester report, for its Zero Trust plan view.

    .DESCRIPTION
    Builds the plan with Get-MtZtaWorkshopPlan from the pack's workshop folder and attaches it to the report as JSON
    named 'zero-trust-workshop', which the report's Zero Trust plan view reads to show each workshop task with the
    status of the checks that measure it.

    It runs in the pack's instance source. Nothing is added when the ZeroTrustAssessment.WorkshopPlan setting is
    false, or on a Maester version whose Add-MtReportAttachment cannot attach JSON. A problem building the plan is a
    warning, never a failed run.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        # The pack's workshop folder. Defaults to the one beside this helper.
        [Parameter()] [string] $WorkshopPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'workshop'),

        # The pack's taxonomy.json. Defaults to the one beside this helper.
        [Parameter()] [string] $TaxonomyPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'taxonomy.json')
    )

    try {
        if (-not [bool](Get-MtSetting -Name 'ZeroTrustAssessment.WorkshopPlan' -Default $true)) { return }
        $command = Get-Command -Name Add-MtReportAttachment -ErrorAction Ignore
        if (-not $command -or -not $command.Parameters.ContainsKey('ContentType')) {
            Write-Verbose 'This version of Maester cannot attach JSON to the report, so the Zero Trust plan is not added.'
            return
        }

        $plan = Get-MtZtaWorkshopPlan -WorkshopPath $WorkshopPath -TaxonomyPath $TaxonomyPath
        if (-not $plan) {
            Write-Verbose "No Zero Trust Workshop data in $WorkshopPath, so the Zero Trust plan is not added."
            return
        }
        $json = $plan | ConvertTo-Json -Depth 10 -Compress
        Add-MtReportAttachment -Name 'zero-trust-workshop' -Content $json -ContentType 'application/json'
    } catch {
        Write-Warning "The Zero Trust plan could not be added to the report: $($_.Exception.Message)"
    }
}
