function Get-MtDynamicGroupCaReference {
    <#
    .SYNOPSIS
    Finds Conditional Access policies that include or exclude specified groups.

    .DESCRIPTION
    Retrieves Conditional Access policies and correlates group identifiers with user includeGroups
    and excludeGroups assignments.

    .EXAMPLE
    Get-MtDynamicGroupCaReference -GroupId $GroupIds
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $GroupId
    )

    $Policies = @(Get-MtConditionalAccessPolicy)

    $References = foreach ($CurrentPolicy in $Policies) {
        foreach ($IncludedGroupId in @($CurrentPolicy.conditions.users.includeGroups)) {
            if ($GroupId -contains $IncludedGroupId) {
                [pscustomobject]@{
                    GroupId  = $IncludedGroupId
                    Condition = 'Include'
                    Policy    = $CurrentPolicy
                }
            }
        }
        foreach ($ExcludedGroupId in @($CurrentPolicy.conditions.users.excludeGroups)) {
            if ($GroupId -contains $ExcludedGroupId) {
                [pscustomobject]@{
                    GroupId  = $ExcludedGroupId
                    Condition = 'Exclude'
                    Policy    = $CurrentPolicy
                }
            }
        }
    }

    return $References
}
