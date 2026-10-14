function Get-MtDynamicGroupCaReferenceMarkdown {
    <#
    .SYNOPSIS
    Formats Conditional Access references for a group as Markdown.

    .DESCRIPTION
    Produces linked include and exclude policy references for test result tables.

    .EXAMPLE
    Get-MtDynamicGroupCaReferenceMarkdown -Reference $References -GroupId $GroupId
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $Reference,

        [Parameter(Mandatory = $true)]
        [string] $GroupId
    )

    $MatchingReferences = @($Reference | Where-Object { $_.GroupId -eq $GroupId })
    if ($MatchingReferences.Count -eq 0) {
        return 'None found'
    }

    $Descriptions = foreach ($CurrentReference in $MatchingReferences) {
        $PolicyLink = Get-GraphObjectMarkdown -GraphObjects $CurrentReference.Policy `
            -GraphObjectType ConditionalAccess -AsPlainTextLink
        "$($CurrentReference.Condition): $PolicyLink ($($CurrentReference.Policy.state))"
    }

    return $Descriptions -join '<br>'
}
