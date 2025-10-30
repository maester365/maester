<#
.SYNOPSIS
    Initializes the MtSession object for the current session so it can be used by other functions.

.DESCRIPTION
    This function will be called for each fresh run of Invoke-Maester.
    It will set the default values for the session.
    The session object is used to store the state of the current session and is used by other functions to access the session state.
#>

function Initialize-MtSession {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Module variables used in other functions.')]
    param()

    $environment = (Get-MgContext).Environment

    # Default to Global if environment is null or empty
    if ([string]::IsNullOrEmpty($environment)) {
        $environment = 'Global'
    }

    $__MtSession.AdminPortalUrl = Get-MtAdminPortalUrl -Environment $environment
}