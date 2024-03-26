<#
.SYNOPSIS
    Validates the MgContext to ensure a valid connection to Microsoft Graph including the required permissions.
#>

function Test-MtContext {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # If specified, the scope will be checked to send email.
        [Parameter(Mandatory = $false)]
        [switch] $SendMail
    )

    $validContext = $true
    if (!(Get-MgContext)) {
        $message = "Not connected to Microsoft Graph. Please use 'Connect-MtGraph'. For more information, use 'Get-Help Connect-MtGraph'."
        $validContext = $false
    } else {
        $requiredScopes = Get-MtGraphScopes -SendMail:$SendMail
        $currentScopes = Get-MgContext | Select-Object -ExpandProperty Scopes
        $missingScopes = $requiredScopes | Where-Object { $currentScopes -notcontains $_ }

        if ($missingScopes) {
            $message = "These Graph permissions are missing in the current connection => ($($missingScopes))."
            if (Get-MtUserInteractive) {
                $message += " Please use 'Connect-MtGraph'. For more information, use 'Get-Help Connect-MtGraph'."
            } else {
                # Assuming it's app permission and running in ADO or GitHub Actions
                #TODO: Check if the connection is delegate or app permission and include deep link to the Entra portal to open the app.
                $message += " Add the missing permissions to the application in the Microsoft Entra portal and grant consent."
            }
            $validContext = $false
        }
    }

    if (!$validContext) {
        Write-Error $message
    }
    return $validContext
}