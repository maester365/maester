<#
.SYNOPSIS
   Write progress to the console based on the current verbosity level.

.DESCRIPTION
   Show updates to the user on the current activity.
#>

function Write-MtProgress {
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
            $statusString = Out-String -InputObject $Status
            # Reduce the length of the status string to fit within host
            $hostWidth = $Host.UI.RawUI.WindowSize.Width
            $buffer = 20
            $totalWidth = $Activity.Length + $statusString.Length + $buffer # 10 for buffer
            if ($totalWidth -gt $hostWidth) {
                $length = $hostWidth - $Activity.Length - $buffer
                if ($length -lt $statusString.Length -and $length -gt 0) {
                    $statusString = $statusString.Substring(0, $length) + "..."
                }
            }

            Write-Progress -Activity $Activity -Status $statusString -Completed:$Completed
            if ($Force -and !$IsWindows) {
                Start-Sleep -Milliseconds 200
                Write-Progress -Activity $Activity -Status $statusString -Completed:$Completed
            }

        } else {
            Write-Progress -Activity $Activity -Completed:$Completed
            if ($Force -and !$IsWindows) {
                Start-Sleep -Milliseconds 200
                Write-Progress -Activity $Activity -Completed:$Completed
            }
        }
    } catch {
        Write-Verbose $_
    }
}