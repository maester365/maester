function Wait-MtTelemetry {
    <#
    .SYNOPSIS
    Gives the telemetry requests still in flight a short time to finish.

    .DESCRIPTION
    Invoke-Maester and Install-MtPack call this as they return, so the last event is not lost when PowerShell exits
    straight after, as it does in a pipeline. It waits only for requests that have not finished, and at most
    -TimeoutSeconds: on a normal network the requests have long finished and it returns at once. A request still
    running after that carries on in the background, and a failed one is ignored.

    .PARAMETER TimeoutSeconds
    The longest time to wait.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [double] $TimeoutSeconds = 2
    )

    if (-not $script:MtTelemetryPending) { return }
    # Finished requests stay in, so WaitAll reports one that failed; it returns at once for them.
    $pending = @($script:MtTelemetryPending)
    $script:MtTelemetryPending.Clear()
    if (-not $pending.Count) { return }
    try {
        $null = [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$pending, [timespan]::FromSeconds($TimeoutSeconds))
    } catch {
        Write-Verbose "Telemetry was not sent: $($_.Exception.InnerException.Message)"
    }
}
