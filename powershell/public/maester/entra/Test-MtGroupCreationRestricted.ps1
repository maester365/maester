<#
.SYNOPSIS
    Checks if Microsoft 365 Group creation is restricted to approved users.

.DESCRIPTION
    By default, all users can create Microsoft 365 Groups. This can lead to sprawl, security risks and compliance issues.

    Creating groups should be restricted to users who have undergone training and understand the responsibilities of group ownership, governance and compliance requirements.

.EXAMPLE
    Test-MtGroupCreationRestricted

    Returns $true if Microsoft 365 Group creation is restricted to approved users, otherwise $false.

.LINK
    https://maester.dev/docs/commands/Test-MtGroupCreationRestricted
#>
function Test-MtGroupCreationRestricted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtGroupCreationRestricted: Checking if Microsoft 365 Group creation is restricted to approved users.'

    try {
        $settings = Invoke-MtGraphRequest -RelativeUri 'settings' -ApiVersion 'beta'

        $groupCreationRestricted = $false

        $enableGroupCreation = $settings.values | Where-Object { $_.name -eq 'EnableGroupCreation' }

        if ($null -ne $enableGroupCreation) {
            # If the setting is not found, it means that group creation is not restricted.
            $groupCreationRestricted = ($enableGroupCreation.value -eq 'false')
        }

        if ($groupCreationRestricted) {
            $testResultMarkdown = 'Well done. Microsoft 365 Group creation is restricted to approved users.'
        } else {
            $testResultMarkdown = 'Microsoft 365 Group creation is not restricted and any user can create groups.'
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $groupCreationRestricted
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
