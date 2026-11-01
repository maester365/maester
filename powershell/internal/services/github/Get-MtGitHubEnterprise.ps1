function Get-MtGitHubEnterprise {
    <#
    .SYNOPSIS
    Internal: Reads enterprise notification settings or one page of matching organizations.
    .DESCRIPTION
    Returns the GraphQL evidence envelope through the session cache. The caller supplies
    the enterprise slug and handles applicability, pagination and assessment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Slug,
        [Parameter(Mandatory)] [ValidateSet('Notification', 'Association')] [string] $Purpose,
        [string] $OrganizationLogin,
        [AllowNull()] [object] $After = $null
    )

    if ($Purpose -eq 'Notification') {
        $query = 'query MaesterCisNotifications($slug:String!){enterprise(slug:$slug){id slug ownerInfo{notificationDeliveryRestrictionEnabledSetting}}}'
        return Invoke-MtGitHubGraphQLRequest -Query $query -Variables @{ slug = $Slug } -OperationName MaesterCisNotifications
    }

    $query = 'query MaesterCisAssociation($slug:String!,$login:String!,$after:String){enterprise(slug:$slug){id slug organizations(first:100,query:$login,after:$after){nodes{id login} pageInfo{hasNextPage endCursor}}}}'
    return Invoke-MtGitHubGraphQLRequest -Query $query -Variables @{ slug = $Slug; login = $OrganizationLogin; after = $After } -OperationName MaesterCisAssociation
}
