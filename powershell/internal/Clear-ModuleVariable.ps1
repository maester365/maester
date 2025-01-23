<#
.SYNOPSIS
    Resets all module variables to their default values.

.DESCRIPTION
    Variables like $MtGraphCache and $MtGraphBaseUri are module-level variables that are cached
    during the running of a test for performance reasons.

    This function will be called for each fresh run of Invoke-Maester.
#>

function Clear-ModuleVariable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Module variables used in other functions.')]
    param()

    Clear-MtGraphCache
    $__MtSession.GraphBaseUri = $null
    $__MtSession.TestResultDetail = @{}
    Clear-MtDnsCache
    Clear-MtExoCache
    # $__MtSession.Connections = @() # Do not clear connections as they are used to track the connection state. This module variable should only be set by Connect-Maester and Disconnect-Maester.
}
