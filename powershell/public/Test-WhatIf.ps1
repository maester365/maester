<#
.SYNOPSIS
    A wrapper function for Test-MtConditionalAccessWhatIf that helps writing pester tests

.DESCRIPTION
    A wrapper function for Test-MtConditionalAccessWhatIf that helps writing pester tests

.PARAMETER User
    User principal name or ObjectId of the user to test

.PARAMETER Application
    ApplicationId of the application to test

.PARAMETER UserAction
    User action to test

.PARAMETER Then
    The expected result of the test

.EXAMPLE
    Test-MtCAWhatIf -User 'admin@domain.com" -Application '00000000-0000-0000-0000-000000000000' -UserAction 'RegisterOrJoinDevices' -Then 'RequireMFA'

#>
function Test-MtCAWhatIf {
    [Alias('Test-WhatIf')]
    [CmdletBinding()]
    param (
        [Alias('UserPrincipalName', 'UserName', 'Id')]
        [Parameter(Mandatory)]
        [string]$User,

        [Alias('ApplicationId', 'AppId')]
        [Parameter(Mandatory)]
        [string]$Application,

        [ValidateSet("RegisterOrJoinDevices", "RegisterSecurityInformation")]
        [string]$UserAction,

        [ValidateSet('Allow', 'Block', 'RequireMFA', 'RequireCompliantDevice', 'RequireEntraHybridJoinedDevice', 'RequireEntraJoinedDevice', 'RequireAppProtectionPolicy', 'RequirePasswordChange')]
        [string[]]$Then

    )

    process {

        try {
            # Check if user is represented by a UPN or ObjectId and resolve to ObjectId if UPN
            if ($User -match '@') {
                $User = Invoke-MgGraphRequest -Method Get -Uri "/v1.0/users/$User" | Select-Object -ExpandProperty Id
            }
        } catch {
            Write-Error "User $User not found"
            return
        }

        Test-MtConditionalAccessWhatIf

    }
}