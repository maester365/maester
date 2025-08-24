<#
.SYNOPSIS
    This test checks if you have any third party service principals that are open to all users. It is recommended to set 'Assignment required?' to Yes for all Third Party apps.

.DESCRIPTION
    Open all app service principals below and set 'Assignment required?' to Yes. Assign users under 'Users and groups' to provide them with explicit access. If desired, use the audit logs per SPN to determine who was using the application before locking them down.

.EXAMPLE
    Test-MtServicePrincipalsForAllUsers

    Returns true if no third party service principals are assigned to All Users, false if any are found.

.LINK
    https://maester.dev/docs/commands/Test-MtServicePrincipalsForAllUsers
#>
function Test-MtServicePrincipalsForAllUsers {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks credentials for all apps.')]
    [OutputType([bool])]
    param(

    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {

        $filter = "not(appOwnerOrganizationId eq 72f988bf-86f1-41af-91ab-2d7cd011db47) and not(appOwnerOrganizationId eq f8cdef31-a31e-4b4a-93e4-5f571e91255a)"
        $filter += " and appRoleAssignmentRequired ne true and accountEnabled eq true"
        $filter += " and (servicePrincipalType eq 'Application' or servicePrincipalType eq 'Legacy')"

        $params = @{
            'RelativeUri'     = 'serviceprincipals'
            'Select'          = 'id,displayName,appId,appRoleAssignmentRequired,appOwnerOrganizationId'
            'Filter'          = $filter
        }

        $spns = Invoke-MtGraphRequest @params

        $return = $spns.Count -eq 0

        if ($return) {
            $testResultMarkdown = 'Well done. No third party service principals that can be used by any user.'
        } else {
            $testResultMarkdown = "You have $($spns.Count) third party service principals that can be used by any user.`n`n%TestResult%"

            Write-Verbose "Found $($spns.Count) third party service principals that can be used by any user."
            Write-Verbose 'Creating markdown table for third party service principals that can be used by any user.'

            $result = "| Application | Application Id |`n"
            $result += "| --- | --- |`n"
            foreach ($spn in $spns) {
                $spnMdLink = "[$($spn.displayName)](https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Properties/objectId/$($spn.id)/appId/$($spn.appId))"
                $result += "| $($spnMdLink) | $($spn.appId) |`n"
                Write-Verbose "Adding service principal $($spn.displayName) with id $($spn.appId) to markdown table."
            }
            $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
