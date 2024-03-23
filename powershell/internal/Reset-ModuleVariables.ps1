<#
.SYNOPSIS
    Resets all module variables to their default values.

.DESCRIPTION
    Variables like $MtGraphCache and $MtGraphBaseUri are module-level variables that are cached
    during the running of a test for performance reasons.

    This function will be called for each fresh run of Invoke-Maester.
#>

Function Reset-ModuleVariables {
    Clear-MtGraphCache
    $MtGraphBaseUri = $null
}
