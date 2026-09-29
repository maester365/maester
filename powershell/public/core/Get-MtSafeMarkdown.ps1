function Get-MtSafeMarkdown {
    <#
	.SYNOPSIS
		Escapes text to be safe to use in markdown.

	.DESCRIPTION
		Escapes text to be safe to use in markdown.

		Use this for any value that comes from the tenant (display names, app names, policy names, etc.)
		before inserting it into test result markdown. Without it, a value such as an app registration
		named '![x](https://attacker.example/pixel.png)' or '[Sign in again](https://phish.example)' would be
		rendered by the report as a remote image or a clickable link, and a '|' would break table layout.

		Characters with meaning in markdown are backslash-escaped and line breaks are replaced with spaces,
		so the value is displayed exactly as entered.

	.PARAMETER Text
		The text to escape

	.EXAMPLE
		PS C:\> Get-MtSafeMarkdown -Text $tenantName

		Converts the content of $tenantName into something safe to use in markdown.

	.EXAMPLE
		PS C:\> "| [$(Get-MtSafeMarkdown $app.displayName)]($portalLink) |"

		Uses a tenant-controlled app name as link text in a markdown table row.

	.LINK
		https://maester.dev/docs/commands/Get-MtSafeMarkdown
	#>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $Text
    )
    Write-Verbose "Escaping markdown text."
    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    # Keep values on a single line so they can't start new markdown blocks or table rows.
    $Text = $Text -replace '\r\n|\r|\n', ' '
    # A single pass, so backslashes added here are never escaped again.
    $Text -replace '([\\`*_\[\]()!|<>~])', '\$1'
}
