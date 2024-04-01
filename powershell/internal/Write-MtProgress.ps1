<#
.SYNOPSIS
   Write progress to the console based on the current verbosity level.

.DESCRIPTION
   Show updates to the user on the current activity.
#>

Function Write-MtProgress {
    [CmdletBinding()]
    Param (
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $false)]
        [object]$Status
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
                if($length -lt $statusString.Length -and $length -gt 0) {
                    $statusString = $statusString.Substring(0, $length) + "..."
                }
            }

            Write-Progress -Activity $Activity -Status $statusString
        } else {
            Write-Progress -Activity $Activity
        }
    } catch {
        Write-Verbose $_
    }
}