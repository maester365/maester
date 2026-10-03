function ConvertTo-MtRedactedReportContent {
    <#
    .SYNOPSIS
    Replaces user identity values in generated report content with stable asset ids.

    .DESCRIPTION
    Applies the replacement map produced by Get-MtUserIdentityReplacementMap to a rendered report
    (json, markdown or html). Values are matched on word boundaries so a short display name never
    rewrites the middle of an unrelated word. Longer values are replaced first so a display name
    that contains another value is not partially replaced.

    When the content is json, the raw value alone is not enough: ConvertTo-Json escapes quotes,
    backslashes and (on Windows PowerShell) non-ASCII characters, so a display name such as
    Jorg "JD" Muller would never match the serialized text. Use -JsonEncoded to also replace the
    serialized form of every value. In that mode only json string values are rewritten, never
    property names, so a user whose display name equals a property ("Severity") cannot break
    the document.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The rendered report content to redact.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Content,

        # Map of value to replace -> replacement token, from Get-MtUserIdentityReplacementMap.
        [Parameter(Mandatory = $true)]
        [hashtable] $ReplacementMap,

        # Also replace the json-escaped form of each value (use when Content is json).
        [Parameter(Mandatory = $false)]
        [switch] $JsonEncoded
    )

    begin {
        # UPNs and object ids are case-insensitive, so a differently cased mention must not slip through.
        $lookup = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($key in $ReplacementMap.Keys) {
            $value = [string]$key
            if ([string]::IsNullOrEmpty($value)) { continue }
            $replacement = [string]$ReplacementMap[$key]
            $lookup[$value] = $replacement
            if ($JsonEncoded) {
                $serialized = [string](ConvertTo-Json -InputObject $value -Compress)
                $lookup[$serialized.Substring(1, $serialized.Length - 2)] = $replacement
            }
        }

        $valuePattern = $null
        if ($lookup.Count -gt 0) {
            # Longest first so a display name that contains another value is replaced whole.
            $alternation = ($lookup.Keys | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|'
            # Word boundaries: a service account named "Test" must not rewrite "TestResult".
            $valuePattern = [regex]::new("(?<![\w-])(?:$alternation)(?![\w-])", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        $replaceValue = [System.Text.RegularExpressions.MatchEvaluator] { param($match) $lookup[$match.Value] }

        # A json string token, plus the colon that follows it when the token is a property name.
        $jsonStringPattern = [regex]::new('"[^"\\]*(?:\\.[^"\\]*)*"(?<key>\s*:)?')
        $replaceJsonString = [System.Text.RegularExpressions.MatchEvaluator] {
            param($match)
            if ($match.Groups['key'].Success) { return $match.Value }
            $valuePattern.Replace($match.Value, $replaceValue)
        }
    }

    process {
        if ([string]::IsNullOrEmpty($Content) -or $null -eq $valuePattern) {
            return $Content
        }

        if ($JsonEncoded) {
            return $jsonStringPattern.Replace($Content, $replaceJsonString)
        }
        return $valuePattern.Replace($Content, $replaceValue)
    }
}
