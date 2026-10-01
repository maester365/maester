function Get-MtAIAgentSkippedReason {
    <#
    .SYNOPSIS
        Returns the skipped reason for a Copilot Studio agent test when no agent data is available.

    .DESCRIPTION
        Get-MtAIAgentInfo records why it could not return agent data (no Dataverse connection, no access
        token, missing permission to read agents, or no agents in the environment) in
        $__MtSession.AIAgentInfoError. This function turns that into the skipped reason shown in the
        report, followed by a link to the test's prerequisites.

    .EXAMPLE
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (Get-MtAIAgentSkippedReason -TestId 'MT.1113')

        Skips MT.1113 with the reason the Copilot Studio agent data could not be retrieved.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # The Maester test id, used to link to the test's prerequisites.
        [Parameter(Mandatory)]
        [string] $TestId
    )

    $reason = $__MtSession.AIAgentInfoError
    if ([string]::IsNullOrEmpty($reason)) {
        $reason = 'No Copilot Studio agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run.'
    }

    return "$reason`n`nSee https://maester.dev/docs/tests/$TestId for prerequisites."
}
