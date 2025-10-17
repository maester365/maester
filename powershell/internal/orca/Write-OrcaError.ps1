function Write-OrcaError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$AdditionalContext = $null
    )

    $errorMessage = "An error occurred during $TestId"

    if ($AdditionalContext) {
        $errorMessage += " ($AdditionalContext)"
    }

    $errorMessage += ": $($ErrorRecord.Exception.Message)"

    # Log additional details for debugging
    Write-Debug "ORCA Test Error Details:"
    Write-Debug "  Test ID: $TestId"
    Write-Debug "  Error Type: $($ErrorRecord.Exception.GetType().Name)"
    Write-Debug "  Stack Trace: $($ErrorRecord.ScriptStackTrace)"

    Write-Error $errorMessage
}