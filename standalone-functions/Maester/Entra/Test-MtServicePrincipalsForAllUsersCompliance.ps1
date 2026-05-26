function Test-MtServicePrincipalsForAllUsersCompliance {
    <#
    .SYNOPSIS
    This test checks if you have any third party service principals that are open to all users. It is recommended to set 'Assignment required?' to Yes for all Third Party apps.

    .DESCRIPTION
    Open all app service principals below and set 'Assignment required?' to Yes. Assign users under 'Users and groups' to provide them with explicit access. If desired, use the audit logs per SPN to determine who was using the application before locking them down.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtServicePrincipalsForAllUsersCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

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
        } else {

            Write-Verbose "Found $($spns.Count) third party service principals that can be used by any user."
            Write-Verbose 'Creating markdown table for third party service principals that can be used by any user.'

            $result = "| Application | Application Id |`n"
            $result += "| --- | --- |`n"
            foreach ($spn in $spns) {
                $spnMdLink = "[$($spn.displayName)](https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Properties/objectId/$($spn.id)/appId/$($spn.appId))"
                $result += "| $($spnMdLink) | $($spn.appId) |`n"
                Write-Verbose "Adding service principal $($spn.displayName) with id $($spn.appId) to markdown table."
            }
        }

        return $return
    } catch {
        return $null
    }

}
