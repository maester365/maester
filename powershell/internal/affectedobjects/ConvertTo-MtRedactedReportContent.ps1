function ConvertTo-MtRedactedReportContent {
    <#
    .SYNOPSIS
    Replaces user identity values in generated report content with stable stable ids.

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
            # Only values with characters ConvertTo-Json escapes (quotes, backslashes, control and
            # non-ASCII characters, and ' < > & on Windows PowerShell) have a different serialized form.
            if ($JsonEncoded -and $value -match '[^\x20-\x7E]|["\\''<>&]') {
                $serialized = [string](ConvertTo-Json -InputObject $value -Compress)
                $lookup[$serialized.Substring(1, $serialized.Length - 2)] = $replacement
            }
        }

        # Object ids and UPNs are matched by shape and looked up in the dictionary, so their number
        # does not affect the speed: a single alternation of every user read from a large tenant
        # took about a minute per output. Only the remaining values (display names and escaped
        # forms, which come from the much smaller affected objects) are listed in the pattern.
        $tokenPattern = '[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}|\w[\w.''+#-]*@[\w-]+(?:\.[\w-]+)*'
        $tokenRegex = [regex]::new("^(?:$tokenPattern)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $phrases = @($lookup.Keys | Where-Object { -not $tokenRegex.IsMatch($_) })

        $valuePattern = $null
        $phrasePattern = $null
        if ($lookup.Count -gt 0) {
            # Word boundaries: a service account named "Test" must not rewrite "TestResult".
            $alternation = $tokenPattern
            if ($phrases.Count -gt 0) {
                # Longest first so a display name that contains another value is replaced whole.
                $phraseAlternation = ($phrases | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|'
                $phrasePattern = [regex]::new("(?<![\w-])(?:$phraseAlternation)(?![\w-])", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                $alternation = "$tokenPattern|$phraseAlternation"
            }
            # Tokens come first so a UPN is replaced whole even when its local part is also a display name.
            $valuePattern = [regex]::new("(?<![\w-])(?:$alternation)(?![\w-])", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        $replaceValue = [System.Text.RegularExpressions.MatchEvaluator] {
            param($match)
            $replacement = $null
            if ($lookup.TryGetValue($match.Value, [ref] $replacement)) { return $replacement }
            # An id or UPN shaped token that is not a known user can still contain a display name.
            if ($phrasePattern) { return $phrasePattern.Replace($match.Value, $replaceValue) }
            return $match.Value
        }

        # A json string token, plus the colon that follows it when the token is a property name.
        $jsonStringPattern = [regex]::new('"[^"\\]*(?:\\.[^"\\]*)*"(?<key>\s*:)?')
        # Windows PowerShell escapes ' < > & as \u0027 \u003c \u003e \u0026. Left in place, the word
        # character before a value ("\u0027Jane Doe\u0027") would defeat the word boundary, so these are
        # decoded for matching and escaped again afterwards.
        $htmlSafeEscape = [regex]::new('\\u00(?:27|3[ce]|26)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $decodeEscape = [System.Text.RegularExpressions.MatchEvaluator] { param($match) [string][char][Convert]::ToInt32($match.Value.Substring(2), 16) }
        $encodeChar = [regex]::new("['<>&]")
        $encodeEscape = [System.Text.RegularExpressions.MatchEvaluator] { param($match) '\u{0:x4}' -f [int][char]$match.Value }
        $replaceJsonString = [System.Text.RegularExpressions.MatchEvaluator] {
            param($match)
            if ($match.Groups['key'].Success) { return $match.Value }
            if (-not $htmlSafeEscape.IsMatch($match.Value)) {
                return $valuePattern.Replace($match.Value, $replaceValue)
            }
            $decoded = $htmlSafeEscape.Replace($match.Value, $decodeEscape)
            $encodeChar.Replace($valuePattern.Replace($decoded, $replaceValue), $encodeEscape)
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
