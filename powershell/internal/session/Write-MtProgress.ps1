function Write-MtProgress {
    <#
    .SYNOPSIS
    Write progress to the console based on the current verbosity level.

    .DESCRIPTION
    Show updates to the user on the current activity.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Required for reporting with colors')]
    [CmdletBinding()]
    Param (
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $false)]
        [object]$Status,

        # Makes sure this message is displayed. On macOS the first progress update of a session is not drawn
        # (https://github.com/PowerShell/PowerShell/issues/5741), so the first forced call waits 200ms and repeats it.
        # Later calls, and calls whose progress is not shown, do not wait.
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        # Specifies that progress is completed.
        [Parameter(Mandatory = $false)]
        [switch]$Completed
    )

    # An interactive Invoke-Maester run shows progress with its console renderer instead of Write-Progress
    # (see Maester.Engine.MtConsoleRenderer for why).
    if ($script:__MtConsoleRenderer) {
        $text = if ($Completed) { $null } elseif ($Status) { ([string]$Status).TrimEnd('.', ' ') } else { $Activity }
        $script:__MtConsoleRenderer.ShowStatus($text)
        return
    }

    try {
        $Activity = "🔥 $Activity"

        # The macOS workaround is needed once per session, and only when progress is drawn on a console.
        $flush = $Force -and $IsMacOS -and -not $script:__MtProgressFlushed -and
            $ProgressPreference -notin 'SilentlyContinue', 'Ignore' -and -not [System.Console]::IsOutputRedirected
        if ($flush) { $script:__MtProgressFlushed = $true }

        if ($Status) {
            $statusString = if ($Status -is [string]) { $Status } else { Out-String -InputObject $Status }

            # Safely get host width with fallback
            $hostWidth = 80 # Default fallback
            try {
                if ($Host.UI.RawUI.WindowSize) {
                    $hostWidth = $Host.UI.RawUI.WindowSize.Width
                }
            } catch {
                Write-Debug "Unable to get host width, using default: $_"
            }

            # Reduce the length of the status string to fit within host
            $buffer = 20
            $totalWidth = $Activity.Length + $statusString.Length + $buffer
            if ($totalWidth -gt $hostWidth) {
                $length = $hostWidth - $Activity.Length - $buffer
                if ($length -gt 0 -and $length -lt $statusString.Length) {
                    $statusString = $statusString.Substring(0, $length).TrimEnd() + "..."
                }
            }

            Write-Progress -Activity $Activity -Status $statusString -Completed:$Completed

            if ($flush) {
                Start-Sleep -Milliseconds 200
                Write-Progress -Activity $Activity -Status $statusString -Completed:$Completed
            }

        } else {
            Write-Progress -Activity $Activity -Completed:$Completed

            if ($flush) {
                Start-Sleep -Milliseconds 200
                Write-Progress -Activity $Activity -Completed:$Completed
            }
        }
    } catch {
        Write-Debug "Error in Write-MtProgress: $($_.Exception.Message)"
        # Fallback to simple Write-Host if Write-Progress fails
        if ($Status) {
            Write-Host "$Activity - $Status" -ForegroundColor Yellow
        } else {
            Write-Host $Activity -ForegroundColor Yellow
        }
    }
}
