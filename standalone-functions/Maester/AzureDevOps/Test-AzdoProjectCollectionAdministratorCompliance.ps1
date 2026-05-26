function Test-AzdoProjectCollectionAdministratorCompliance {
    <#
    .SYNOPSIS
    Returns a list of all Project Collection Administrators.

    .DESCRIPTION
    Checks the status of how many Project Collection Administrators that are assigned to your Azure DevOps organisation.

    https://learn.microsoft.com/en-us/azure/devops/organizations/security/about-permissions?view=azure-devops&tabs=preview-page#permissions
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoProjectCollectionAdministratorCompliance
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
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoProjectCollectionAdministrator"


    function Get-NestedAdoMembership {
        param (
            [Parameter()]
            $Member
        )

        if ($Member.subjectKind -eq 'group') {
            Write-Verbose "Finding members in group '$($Member.DisplayName)' - Descriptor '$($Member.Descriptor)'"
            Get-ADOPSMembership -Descriptor $Member.descriptor -Direction 'down' | Foreach-object {
                Write-Verbose "Processing member '$($_.DisplayName)' - Descriptor '$($_.Descriptor)'"
                Get-NestedAdoMembership -Member $_
            }
        } else {
            Write-output $Member
        }
    }

    $PCA = Get-ADOPSGroup | Where-object -Property displayname -eq 'Project Collection Administrators'
    $PCAMembers = Get-ADOPSMembership -Descriptor $PCA.descriptor -Direction 'down'

    # UniqueUserList
    $UniqueUsersWithPCA = New-Object System.Collections.Arraylist

    # Users with PCA
    $UserPCA = $PCAMembers | Where-Object { $_.subjectKind -ne 'group' }
    $UserPCA | Foreach-object {
        $UniqueUsersWithPCA.Add($_) | Out-Null
    }

    # Groups with PCA
    $GroupPCA = $PCAMembers | Where-Object { $_.subjectKind -eq 'group' }

    $GroupPCA | Foreach-object {
        Get-NestedAdoMembership -Member $_ | Foreach-object {
            if ($_.descriptor -notin $UniqueUsersWithPCA.descriptor) {
                $UniqueUsersWithPCA.Add($_) | Out-Null
            } else {
                Write-Verbose "$($_.subjectKind) - $($_.displayname) - $($_.descriptor) - has already been added."
            }
        }

    }

    if ($UniqueUsersWithPCA.Count -ge 4) {
        $result = $false
    } else {
        $result = $true
    }
    $UniqueUsersWithPCA | ForEach-Object -Begin {
        $markdown = "| DisplayName | Alias | E-mail |`n"
        $markdown += "| --- | --- | --- |`n"
    } -Process {
        $markdown += "| $($_.displayName) | $($_.directoryAlias) | $($_.mailAddress) |`n"
    } -end {
    }


    return $result

}
