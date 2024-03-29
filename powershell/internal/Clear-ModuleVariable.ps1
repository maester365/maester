<#
.SYNOPSIS
    Resets all module variables to their default values.

.DESCRIPTION
    Variables like $MtGraphCache and $MtGraphBaseUri are module-level variables that are cached
    during the running of a test for performance reasons.

    This function will be called for each fresh run of Invoke-Maester.
#>

Function Clear-ModuleVariable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Module variables used in other functions.')]
    param()

    Clear-MtGraphCache
    $MtGraphBaseUri = $null
    $MtTestResultDetail = @{}
}
