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

		Characters with meaning in markdown are backslash-escaped, and so are the ones that make GFM
		turn text into a link on its own: a bare 'https://host', 'ftp://host', 'www.host', 'a@b' or
		'mailto:a@b' is an autolink literal, not markdown syntax, and the report renders with
		'gfm: true'. Line breaks are replaced with spaces. Every backslash added here is consumed by
		the renderer, so the value is displayed exactly as entered.

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
    # Two passes, and the order matters. The first escapes every character that is either
    # markdown syntax or part of an autolink literal; it runs once, so the backslashes it
    # adds are never escaped again. The second handles the one autolink form that contains
    # no such character: GFM links a bare `www.host`, so the dot after `www` is escaped
    # too. It cannot double-escape, because it only ever matches a dot.
    #
    # `:` and `@` are not markdown syntax. They are here because the report renders with
    # `gfm: true`, so `https://host`, `ftp://host`, `mailto:a@b` and a bare `a@b` in a
    # tenant-controlled name each render as a live link without them. A plain `contoso.com`
    # is deliberately left alone: GFM does not autolink it, and escaping every dot would be
    # noise in the JSON output for no gain.
    ($Text -replace '([\\`*_\[\]()!|<>~:@])', '\$1') -replace '(?<=\bwww)\.', '\.'
}
