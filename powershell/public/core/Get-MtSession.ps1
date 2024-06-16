<#
 .SYNOPSIS
    Gets the current Maester session information which includes the current Graph base uri and other details.
    These are read-only and should not be modified directly.

 .DESCRIPTION
    The session information can be used to troubleshoot issues with the Maester module.

 .EXAMPLE
    Get-MtSession

    Returns the current Maester session information.
#>

Function Get-MtSession {
    Write-Output $__MtSession
}