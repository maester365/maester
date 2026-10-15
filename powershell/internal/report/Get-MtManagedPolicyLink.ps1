function Get-MtManagedPolicyLink {
    <#
    .SYNOPSIS
    Returns a Markdown link to a Conditional Access policy that is safe to use in a table cell.

    .DESCRIPTION
    Escapes pipe characters in the policy name so the link does not break a Markdown table, then returns a
    link to the policy in the Microsoft Entra admin center.

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
        displayName = $Policy.displayName -replace '\|', '\|'
    }
    return Get-GraphObjectMarkdown -GraphObjects $SafePolicy -GraphObjectType ConditionalAccess -AsPlainTextLink
}
