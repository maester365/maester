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

    if($Status){
        $statusString = Out-String -InputObject $Status
        Write-Progress -Activity $Activity -Status $statusString
    }
    else{
        Write-Progress -Activity $Activity
    }

}