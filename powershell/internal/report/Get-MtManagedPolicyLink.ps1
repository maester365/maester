function Get-MtManagedPolicyLink {
    <#
    .SYNOPSIS
    Returns a Markdown link to a Conditional Access policy that is safe to use in a report table.

    .DESCRIPTION
    Escapes Markdown-significant characters in the policy name with Get-MtSafeMarkdown so the name cannot
    break a Markdown table or the link text, then returns a link to the policy in the Microsoft Entra admin
    center.

    .EXAMPLE
    Get-MtManagedPolicyLink -Policy $Policy
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The Conditional Access policy to link to.
        [Parameter(Mandatory)]
        [object] $Policy
    )

    $SafePolicy = [pscustomobject]@{
        id          = $Policy.id
        displayName = Get-MtSafeMarkdown -Text $Policy.displayName
    }
    return Get-GraphObjectMarkdown -GraphObjects $SafePolicy -GraphObjectType ConditionalAccess -AsPlainTextLink
}
