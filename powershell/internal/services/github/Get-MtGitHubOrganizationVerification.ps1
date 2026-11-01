function Get-MtGitHubOrganizationVerification {
    <#
    .SYNOPSIS
    Internal: Reads organization identity and profile verification evidence.
    .DESCRIPTION
    Returns the GraphQL evidence envelope through the session cache. The caller supplies
    the organization login and handles applicability and assessment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Login
    )

    $query = 'query MaesterCisVerification($login:String!){organization(login:$login){id login isVerified}}'
    return Invoke-MtGitHubGraphQLRequest -Query $query -Variables @{ login = $Login } -OperationName MaesterCisVerification
}
