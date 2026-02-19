<#
.SYNOPSIS
    Returns a list of all Project Collection Administrators.

.DESCRIPTION
    Checks the status of how many Project Collection Administrators that are assigned to your Azure DevOps organisation.

    https://learn.microsoft.com/en-us/azure/devops/organizations/security/about-permissions?view=azure-devops&tabs=preview-page#permissions

.EXAMPLE
    ```
    Test-AzdoProjectCollectionAdministrator
    ```

    Returns a list of all Project Collection Administrators.

.LINK
    https://maester.dev/docs/commands/Test-AzdoProjectCollectionAdministrator
#>
function Test-AzdoProjectCollectionAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-verbose 'Not connected to Azure DevOps'

    function Get-NestedAdoMembership {
        param (
            [Parameter()]
            $Member
        )

        if ($Member.subjectKind -eq 'group') {
            Write-Verbose "Finding members in group '$($Member.DisplayName)' - Descriptor '$($_.Descriptor)'"
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
        $resultMarkdown = "Restrict direct user access ('$($UniqueUsersWithPCA.Count)') to Project Collection Administrators role. The role holds the highest authority within an organization or project collection. Members can Perform all operations for the entire collection, Manage settings, policies, and processes for the organization, create and manage all projects and extensions.`n`n%TestResult%"
    } else {
        $result = $true
        $resultMarkdown = "Well done. Less than 4 users/service accounts are directly assigned to the Project Collection Administrators role.`n`n%TestResult%"
    }
    $UniqueUsersWithPCA | ForEach-Object -Begin {
        $markdown = "| DisplayName | Alias | E-mail |`n"
        $markdown += "| --- | --- | --- |`n"
    } -Process {
        $markdown += "| $($_.displayName) | $($_.directoryAlias) | $($_.mailAddress) |`n"
    } -end {
        $resultMarkdown = $resultMarkdown -replace '%TestResult%', $markdown
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}