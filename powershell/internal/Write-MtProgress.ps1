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

    if ($Status) {
        $statusString = Out-String -InputObject $Status
        # Reduce the length of the status string to 50 characters
        $hostWidth = $Host.UI.RawUI.WindowSize.Width
        $buffer = 5
        $totalWidth = $Activity.Length + $statusString.Length + $buffer # 10 for buffer
        if ($totalWidth -gt $hostWidth) {
            $statusString = $statusString.Substring(0, [Math]::Min($statusString.Length, $hostWidth - $Activity.Length - $buffer)) + "..."
        }

        Write-Progress -Activity $Activity -Status $statusString
    } else {
        Write-Progress -Activity $Activity
    }

}