<#
.SYNOPSIS
   Write progress to the console based on the current verbosity level.

.DESCRIPTION
   Show updates to the user on the current activity.
#>

function Write-MtProgress {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Required for reporting with colors')]
    [CmdletBinding()]
    Param (
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $false)]
        [object]$Status,

        # Forces this message to be displayed by adding a 200ms sleep for the update to be displayed
        # Use sparingly as it can slow down the script
        # This is a workaround for bug on macOS where first call does not show the progress bar. See https://github.com/PowerShell/PowerShell/issues/5741
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        # Specifies that progress is completed.
        [Parameter(Mandatory = $false)]
        [switch]$Completed
    )

    try {
        $Activity = "🔥 $Activity"

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

            # Improved macOS workaround - only apply when needed
            if ($Force -and $IsMacOS) {
                Start-Sleep -Milliseconds 200
                Write-Progress -Activity $Activity -Status $statusString -Completed:$Completed
            }

        } else {
            Write-Progress -Activity $Activity -Completed:$Completed

            # Improved macOS workaround - only apply when needed
            if ($Force -and $IsMacOS) {
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