<#
 .SYNOPSIS
    Gets the current Maester session information which includes the current Graph base uri and other details.
    These are read-only and should not be modified directly.

 .DESCRIPTION
    The session information can be used to troubleshoot issues with the Maester module.

 .EXAMPLE
    Get-MtSession

    Returns the current Maester session information.

.LINK
    https://maester.dev/docs/commands/Get-MtSession
#>
function Get-MtSession {
    [CmdletBinding()]
    param()

    Write-Verbose 'Getting the current Maester session information.'
    Write-Output $__MtSession
}