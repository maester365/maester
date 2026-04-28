function Get-MtSafeMarkdown {
    <#
	.SYNOPSIS
		Escapes text to be safe to use in markdown.

	.DESCRIPTION
		Escapes text to be safe to use in markdown.

	.PARAMETER Text
		The text to escape

	.EXAMPLE
		PS C:\> Get-MtSafeMarkdown -Text $tenantName

		Converts the content of $tenantName into something safe to use in markdown.

	.LINK
		https://maester.dev/docs/commands/Get-MtSafeMarkdown
	#>
    [CmdletBinding()]
    [OutputType()]
    param (
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $Text
    )
    Write-Verbose "Escaping markdown text."
    $Text -replace "\[", "\[" -replace "\]", "\]"
}
