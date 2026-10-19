<#
.SYNOPSIS
Reviews the rubric attributes of new and changed Maester tests with a reviewer model.

.DESCRIPTION
For every test that is new, or whose rubric attributes changed, this script sends the test's attribute values,
its source and its Markdown file to the Claude API together with the attribute rubric
(website/docs/writing-tests/attribute-rubric.md) and the taxonomy (powershell/assets/MaesterTaxonomy.psd1), and
asks whether each value fits the rubric. It also sends the rubric attributes of the other tests under -Root with the
same Product and Feature, so that the model can hold the test to the same value as the same check in another suite. It writes attribute-review.json and attribute-review.md and returns:

    0  every reviewed attribute fits the rubric, or nothing needed review
    1  at least one attribute does not fit the rubric
    2  the review could not be completed (no API key, API error, refusal, unreadable file)

The files under review are treated as data. They are parsed with the PowerShell parser and never executed, and
the rubric, the taxonomy and the reviewer prompt are always read from -Root. In a pull request workflow -Root is
a checkout of the base branch and -HeadRoot holds the downloaded files of the pull request.

The API key is read from the ANTHROPIC_API_KEY environment variable.

.PARAMETER Root
The trusted repository root. The rubric, the taxonomy and the reviewer prompt are read from here.

.PARAMETER HeadRoot
The folder that holds the versions under review, laid out like the repository. Defaults to -Root.

.PARAMETER BaseRef
A git ref to compare with, for example origin/main. Used when -HeadRoot is the working tree. Without it, and with
-HeadRoot equal to -Root, every listed test is reviewed as new.

.PARAMETER File
Test files to consider, relative to the repository root (Test.<ID>.ps1 or Test.<ID>.md). When omitted and
-BaseRef is given, the files changed since that ref are used.

.PARAMETER OutputPath
Folder for attribute-review.json and attribute-review.md. Defaults to the current folder.

.PARAMETER Model
The Claude model to use.

.PARAMETER Effort
The effort level passed to the model.

.PARAMETER MaxTests
The largest number of tests to review in one run. More than this returns 2 without calling the API.

.PARAMETER SkipWhenNoKey
Return 0 with a notice, instead of 2, when ANTHROPIC_API_KEY is not set.

.EXAMPLE
./build/review/Invoke-MtAttributeReview.ps1 -BaseRef origin/main

Reviews the tests you added or whose attributes you changed since origin/main.

.EXAMPLE
./build/review/Invoke-MtAttributeReview.ps1 -File tests/maester/entra/Test.MT.1012.ps1

Reviews every rubric attribute of one test.
#>
[CmdletBinding()]
param(
    [string] $Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,

    [string] $HeadRoot,

    [string] $BaseRef,

    [string[]] $File,

    [string] $OutputPath = (Get-Location).Path,

    [string] $Model = $(if ($env:MAESTER_REVIEW_MODEL) { $env:MAESTER_REVIEW_MODEL } else { 'claude-opus-5-5' }),

    [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')]
    [string] $Effort = 'high',

    [ValidateRange(1, 500)]
    [int] $MaxTests = 25,

    [switch] $SkipWhenNoKey
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The attributes the rubric governs. Everything else on [MaesterTest] is mechanical and checked by unit tests.
$script:RubricAttribute = @('Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType', 'Severity',
    'UserImpact', 'ImplementationCost', 'Mitre')

# A test file larger than this is not sent. It is reported as not reviewable instead of being cut short.
$script:MaxSourceLength = 120000
$script:MaxMarkdownLength = 60000

function Get-MtReviewAttribute {
    <#
    .SYNOPSIS
    Reads the [MaesterTest(...)] named arguments from the text of a test file without running it.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [string] $Content
    )

    $result = [pscustomobject]@{ Found = $false; Attributes = [ordered]@{}; Error = $null }
    if ([string]::IsNullOrWhiteSpace($Content)) {
        $result.Error = 'The file is empty.'
        return $result
    }
    # A using statement makes the parser resolve modules and assemblies. A test file never needs one, so such a
    # file is refused before it reaches the parser.
    if ($Content -match '(?im)^\s*using\s+(module|assembly|namespace)\b') {
        $result.Error = 'The file has a using statement. Test files contain function definitions only.'
        return $result
    }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref] $tokens, [ref] $parseErrors)
    $attribute = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AttributeAst] -and
            $node.TypeName.Name -in 'MaesterTest', 'MaesterTestAttribute'
        }, $true) | Select-Object -First 1
    if (-not $attribute) {
        $result.Error = 'No [MaesterTest(...)] attribute was found.'
        return $result
    }

    $result.Found = $true
    foreach ($argument in $attribute.NamedArguments) {
        if ($argument.ExpressionOmitted) {
            $result.Attributes[$argument.ArgumentName] = $true
            continue
        }
        $expression = $argument.Argument
        while ($expression -is [System.Management.Automation.Language.ParenExpressionAst]) {
            $element = $expression.Pipeline.PipelineElements | Select-Object -First 1
            if ($element -isnot [System.Management.Automation.Language.CommandExpressionAst]) { break }
            $expression = $element.Expression
        }
        $elements = if ($expression -is [System.Management.Automation.Language.ArrayLiteralAst]) { $expression.Elements } else { @($expression) }
        $values = foreach ($e in $elements) {
            if ($e -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $e.Value }
            elseif ($e -is [System.Management.Automation.Language.VariableExpressionAst] -and $e.VariablePath.UserPath -in 'true', 'false') { $e.VariablePath.UserPath -eq 'true' }
            else { '<not a constant>' }
        }
        $result.Attributes[$argument.ArgumentName] = if ($expression -is [System.Management.Automation.Language.ArrayLiteralAst]) { , @($values) } else { $values }
    }
    $result
}

function ConvertTo-MtReviewValue {
    <#
    .SYNOPSIS
    Writes an attribute value the way it is compared and shown: a list becomes its sorted elements joined by ', '.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        $Value
    )
    if ($null -eq $Value) { return '' }
    if ($Value -is [array]) { return (@($Value | ForEach-Object { "$_".Trim() } | Sort-Object -Unique) -join ', ') }
    "$Value".Trim()
}

function Get-MtReviewContent {
    <#
    .SYNOPSIS
    Returns the head and base text of one repository-relative file, or $null for a side that does not have it.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string] $Root,
        [string] $HeadRoot,
        [string] $BaseRef,
        [string] $RelativePath
    )

    $sameTree = (Resolve-Path $HeadRoot).Path -eq (Resolve-Path $Root).Path
    $headFile = Join-Path $HeadRoot $RelativePath
    $rootFile = Join-Path $Root $RelativePath

    $head = if (Test-Path -LiteralPath $headFile -PathType Leaf) { Get-Content -LiteralPath $headFile -Raw }
    # A pull request that changed only the Markdown file does not carry the .ps1; the base copy is the current one.
    elseif (-not $sameTree -and (Test-Path -LiteralPath $rootFile -PathType Leaf)) { Get-Content -LiteralPath $rootFile -Raw }
    else { $null }

    $base = $null
    if ($BaseRef) {
        $shown = & git -C $Root show "$($BaseRef):$($RelativePath -replace '\\', '/')" 2>$null
        if ($LASTEXITCODE -eq 0) { $base = $shown -join "`n" }
    } elseif (-not $sameTree -and (Test-Path -LiteralPath $rootFile -PathType Leaf)) {
        $base = Get-Content -LiteralPath $rootFile -Raw
    }

    [pscustomobject]@{ Head = $head; Base = $base }
}

function Get-MtReviewTarget {
    <#
    .SYNOPSIS
    Works out which tests need review and what changed in each.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string] $Root,
        [string] $HeadRoot,
        [string] $BaseRef,
        [string[]] $File
    )

    # Test.<ID>.ps1 and Test.<ID>.md describe one test. Any other path is ignored.
    $testPaths = $File |
        Where-Object { $_ } |
        ForEach-Object { $_ -replace '\\', '/' } |
        Where-Object { $_ -match '^tests/.+/Test\.[^/]+\.(ps1|md)$' -and $_ -notmatch '(^|/)\.\.(/|$)' } |
        ForEach-Object { $_ -replace '\.md$', '.ps1' } |
        Sort-Object -Unique

    foreach ($path in $testPaths) {
        $source = Get-MtReviewContent -Root $Root -HeadRoot $HeadRoot -BaseRef $BaseRef -RelativePath $path
        if ($null -eq $source.Head) { continue } # the test was deleted
        $markdown = Get-MtReviewContent -Root $Root -HeadRoot $HeadRoot -BaseRef $BaseRef -RelativePath ($path -replace '\.ps1$', '.md')

        $target = [pscustomobject]@{
            Path     = $path
            Id       = [System.IO.Path]::GetFileNameWithoutExtension($path) -replace '^Test\.', ''
            IsNew    = $null -eq $source.Base
            Changed  = @()
            Declared = [ordered]@{}
            Previous = $null
            Source   = $source.Head
            Markdown = $markdown.Head
            Related  = @()
            Error    = $null
        }

        $declared = Get-MtReviewAttribute -Content $source.Head
        if ($declared.Error) {
            $target.Error = $declared.Error
            $target
            continue
        }
        foreach ($name in $script:RubricAttribute) {
            if ($declared.Attributes.Contains($name)) { $target.Declared[$name] = $declared.Attributes[$name] }
        }
        if ($declared.Attributes.Contains('Id')) { $target.Id = [string] $declared.Attributes['Id'] }

        if ($target.IsNew) {
            $target.Changed = @($script:RubricAttribute)
        } else {
            $previous = Get-MtReviewAttribute -Content $source.Base
            $target.Previous = [ordered]@{}
            foreach ($name in $script:RubricAttribute) {
                if ($previous.Attributes.Contains($name)) { $target.Previous[$name] = $previous.Attributes[$name] }
                $before = ConvertTo-MtReviewValue -Value $(if ($previous.Attributes.Contains($name)) { $previous.Attributes[$name] })
                $after = ConvertTo-MtReviewValue -Value $(if ($declared.Attributes.Contains($name)) { $declared.Attributes[$name] })
                if ($before -cne $after) { $target.Changed += $name }
            }
            if ($target.Changed.Count -eq 0) { continue } # nothing the rubric governs changed
        }

        if ($target.Source.Length -gt $script:MaxSourceLength -or ($target.Markdown -and $target.Markdown.Length -gt $script:MaxMarkdownLength)) {
            $target.Error = 'The test is too large to review automatically. Ask a maintainer to review its attributes.'
        }
        $target
    }
}

function Get-MtReviewIndex {
    <#
    .SYNOPSIS
    Reads the id, title and rubric attributes of every test under -Root, without running any of them.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string] $Root
    )

    $testsFolder = Join-Path $Root 'tests'
    if (-not (Test-Path -LiteralPath $testsFolder -PathType Container)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $testsFolder -Filter 'Test.*.ps1' -File -Recurse) {
        $read = Get-MtReviewAttribute -Content (Get-Content -LiteralPath $file.FullName -Raw)
        if ($read.Error) { continue }
        $entry = [ordered]@{
            Id    = if ($read.Attributes.Contains('Id')) { [string] $read.Attributes['Id'] } else { $file.BaseName -replace '^Test\.', '' }
            Title = if ($read.Attributes.Contains('Title')) { [string] $read.Attributes['Title'] } else { '' }
        }
        foreach ($name in $script:RubricAttribute) {
            if ($read.Attributes.Contains($name)) { $entry[$name] = $read.Attributes[$name] }
        }
        [pscustomobject]$entry
    }
}

function Get-MtReviewRelatedTest {
    <#
    .SYNOPSIS
    Returns the other tests with the same Product and Feature as the target, so the reviewer can compare a test
    with the same check in another suite.

    .DESCRIPTION
    The values come from -Index, which is read from the trusted root. A test that the pull request also changes
    is shown with its values from the pull request, so that a change made to both tests is not reported against
    the old value.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [pscustomobject] $Target,
        [AllowEmptyCollection()]
        [object[]] $Index,
        [AllowEmptyCollection()]
        [object[]] $Changed,
        [int] $MaxRelated = 40
    )

    $product = ConvertTo-MtReviewValue -Value $(if ($Target.Declared.Contains('Product')) { $Target.Declared['Product'] })
    $feature = ConvertTo-MtReviewValue -Value $(if ($Target.Declared.Contains('Feature')) { $Target.Declared['Feature'] })
    if (-not $product -or -not $feature) { return }

    $overlay = @{}
    foreach ($other in $Changed) {
        if ($other -and -not $other.Error -and $other.Id -ne $Target.Id) { $overlay[$other.Id] = $other.Declared }
    }

    $related = foreach ($entry in $Index) {
        if ($entry.Id -eq $Target.Id) { continue }
        $values = if ($overlay.ContainsKey($entry.Id)) { $overlay[$entry.Id] } else { $entry }
        $shown = [ordered]@{}
        foreach ($name in $script:RubricAttribute) {
            $value = if ($values -is [System.Collections.IDictionary]) { if ($values.Contains($name)) { $values[$name] } } elseif ($values.PSObject.Properties[$name]) { $values.$name }
            $shown[$name] = ConvertTo-MtReviewValue -Value $value
        }
        if ($shown['Product'] -ne $product -or $shown['Feature'] -ne $feature) { continue }
        $item = [ordered]@{ Id = $entry.Id; Title = $entry.Title }
        foreach ($name in $script:RubricAttribute) {
            if ($name -notin 'Product', 'Feature' -and $shown[$name]) { $item[$name] = $shown[$name] }
        }
        [pscustomobject]$item
    }
    @($related | Sort-Object -Property Id | Select-Object -First $MaxRelated)
}

function Get-MtReviewSystem {
    <#
    .SYNOPSIS
    Builds the system prompt: the reviewer instructions, then the rubric and the taxonomy as one cached block.
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [string] $Root
    )

    $prompt = Get-Content -LiteralPath (Join-Path $Root 'build/review/attribute-review-prompt.md') -Raw
    $rubric = Get-Content -LiteralPath (Join-Path $Root 'website/docs/writing-tests/attribute-rubric.md') -Raw
    $rubric = $rubric -replace '(?s)\A---\r?\n.*?\r?\n---\r?\n', ''
    $taxonomy = Import-PowerShellDataFile -LiteralPath (Join-Path $Root 'powershell/assets/MaesterTaxonomy.psd1')

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Taxonomy')
    $lines.Add('')
    $lines.Add('## Products and their features')
    foreach ($product in $taxonomy.Products) {
        $features = @($product.Features | ForEach-Object { "``$($_.Key)`` ($($_.Name))" }) -join ', '
        $lines.Add("- ``$($product.Key)`` ($($product.Name)): $features")
    }
    $lines.Add('')
    $lines.Add('## Areas')
    foreach ($area in $taxonomy.Areas) { $lines.Add("- ``$($area.Key)`` ($($area.Name)): $($area.Description)") }
    $lines.Add('')
    $lines.Add('## Resource types')
    foreach ($type in $taxonomy.ResourceTypes) { $lines.Add("- ``$($type.Key)``: $($type.Description)") }

    @(
        @{ type = 'text'; text = $prompt.Trim() }
        @{ type = 'text'; text = ($rubric.Trim() + "`n`n" + ($lines -join "`n")); cache_control = @{ type = 'ephemeral' } }
    )
}

function New-MtReviewRequestBody {
    <#
    .SYNOPSIS
    Builds the Messages API request for one test.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory request; changes nothing.')]
    param(
        [pscustomobject] $Target,
        [object[]] $System,
        [string] $Model,
        [string] $Effort
    )

    # The tag names carry a random number so that text inside a file cannot close the tag and pose as instructions.
    $nonce = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(100000000, 999999999)
    $previous = if ($Target.IsNew) { 'none' } else { $Target.Previous | ConvertTo-Json -Depth 4 -Compress }
    $markdown = if ($Target.Markdown) { $Target.Markdown } else { '(the test has no Markdown file)' }
    $related = if (@($Target.Related).Count -gt 0) { ConvertTo-Json -InputObject @($Target.Related) -Depth 4 -Compress } else { 'none' }
    $user = @(
        "Review this $(if ($Target.IsNew) { 'new' } else { 'changed' }) test: $($Target.Id) ($($Target.Path))."
        ''
        "attributes_to_review: $($Target.Changed -join ', ')"
        "declared_attributes: $($Target.Declared | ConvertTo-Json -Depth 4 -Compress)"
        "previous_attributes: $previous"
        "related_tests: $related"
        ''
        "<test_source_$nonce>"
        $Target.Source
        "</test_source_$nonce>"
        ''
        "<test_markdown_$nonce>"
        $markdown
        "</test_markdown_$nonce>"
    ) -join "`n"

    $schema = [ordered]@{
        type                 = 'object'
        properties           = [ordered]@{
            verdict                = @{ type = 'string'; enum = @('pass', 'fail') }
            findings               = @{
                type  = 'array'
                items = [ordered]@{
                    type                 = 'object'
                    properties           = [ordered]@{
                        attribute = @{ type = 'string'; enum = @($script:RubricAttribute) }
                        declared  = @{ type = 'string' }
                        expected  = @{ type = 'string' }
                        reason    = @{ type = 'string' }
                    }
                    required             = @('attribute', 'declared', 'expected', 'reason')
                    additionalProperties = $false
                }
            }
            notes                  = @{ type = 'array'; items = @{ type = 'string' } }
            untrusted_instructions = @{ type = 'boolean' }
        }
        required             = @('verdict', 'findings', 'notes', 'untrusted_instructions')
        additionalProperties = $false
    }

    [ordered]@{
        model         = $Model
        max_tokens    = 16000
        system        = $System
        messages      = @(@{ role = 'user'; content = $user })
        output_config = [ordered]@{
            effort = $Effort
            format = [ordered]@{ type = 'json_schema'; schema = $schema }
        }
        # If the model declines the request, the API reruns it on Anthropic's recommended fallback model.
        fallbacks     = 'default'
    }
}

function Invoke-MtReviewRequest {
    <#
    .SYNOPSIS
    Sends one request to the Claude Messages API and returns the parsed response. Retries rate limits and server errors.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [System.Collections.IDictionary] $Body,
        [string] $ApiKey,
        [int] $MaxAttempts = 4
    )

    $headers = @{
        'x-api-key'         = $ApiKey
        'anthropic-version' = '2023-06-01'
        'anthropic-beta'    = 'server-side-fallback-2026-07-01'
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 30 -Compress))

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $response = Invoke-WebRequest -Method Post -Uri 'https://api.anthropic.com/v1/messages' -Headers $headers `
            -Body $bytes -ContentType 'application/json' -SkipHttpErrorCheck -TimeoutSec 600
        $status = [int] $response.StatusCode
        if ($status -eq 200) { return ($response.Content | ConvertFrom-Json -Depth 30) }

        $apiError = try { ($response.Content | ConvertFrom-Json -Depth 10).error } catch { $null }
        $message = if ($apiError) { "$($apiError.type): $($apiError.message)" } else { "HTTP $status" }
        $retryable = $status -in 408, 409, 429, 500, 502, 503, 504, 529
        if (-not $retryable -or $attempt -eq $MaxAttempts) {
            throw "The Claude API returned $status ($message)."
        }
        $retryAfter = 0
        $header = $response.Headers['retry-after'] | Select-Object -First 1
        if (-not ($header -and [int]::TryParse($header, [ref] $retryAfter))) { $retryAfter = [math]::Pow(2, $attempt) * 2 }
        Start-Sleep -Seconds ([math]::Min([math]::Max($retryAfter, 1), 120))
    }
}

function ConvertFrom-MtReviewResponse {
    <#
    .SYNOPSIS
    Turns an API response into the result for one test. The script, not the model, decides pass or fail.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [pscustomobject] $Target,
        [AllowNull()]
        $Response
    )

    $result = [pscustomobject]@{
        Id       = $Target.Id
        Path     = $Target.Path
        IsNew    = $Target.IsNew
        Reviewed = @($Target.Changed)
        Outcome  = 'Error'
        Findings = @()
        Notes    = @()
        Error    = $null
        Model    = $null
    }
    if ($null -eq $Response) {
        $result.Error = 'No response.'
        return $result
    }
    $result.Model = $Response.model
    if ($Response.stop_reason -eq 'refusal') {
        $result.Error = 'The reviewer model declined to review this test.'
        return $result
    }
    if ($Response.stop_reason -eq 'max_tokens') {
        $result.Error = 'The review was cut off before it finished.'
        return $result
    }
    $text = $Response.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1 -ExpandProperty text
    $review = try { $text | ConvertFrom-Json -Depth 10 } catch { $null }
    if ($null -eq $review -or $null -eq $review.PSObject.Properties['findings']) {
        $result.Error = 'The reviewer model did not return a readable review.'
        return $result
    }

    $result.Notes = @($review.notes | Where-Object { $_ })
    foreach ($finding in @($review.findings)) {
        if ($finding.attribute -in $Target.Changed) {
            $result.Findings += [pscustomobject]@{
                Attribute = [string] $finding.attribute
                Declared  = [string] $finding.declared
                Expected  = [string] $finding.expected
                Reason    = [string] $finding.reason
            }
        } else {
            # A remark on an attribute that did not change does not block the pull request.
            $result.Notes += "$($finding.attribute): $($finding.reason)"
        }
    }
    if ($review.untrusted_instructions) {
        $result.Findings += [pscustomobject]@{
            Attribute = 'Files'
            Declared  = 'Text addressed to the reviewer'
            Expected  = 'None'
            Reason    = 'The test files contain text that tries to steer the review. Remove it.'
        }
    }
    $result.Outcome = if ($result.Findings.Count -gt 0 -or $review.verdict -eq 'fail') { 'Fail' } else { 'Pass' }
    if ($result.Outcome -eq 'Fail' -and $result.Findings.Count -eq 0) {
        $result.Findings += [pscustomobject]@{ Attribute = 'Review'; Declared = ''; Expected = ''; Reason = 'The reviewer failed the test without naming an attribute. See the notes.' }
    }
    $result
}

function ConvertTo-MtReviewCell {
    <#
    .SYNOPSIS
    Makes model-written text safe for a Markdown table cell in a pull request comment.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Text,
        [int] $MaxLength = 600
    )
    if (-not $Text) { return '' }
    $clean = ($Text -replace '\s+', ' ').Trim()
    if ($clean.Length -gt $MaxLength) { $clean = $clean.Substring(0, $MaxLength) + '...' }
    # No table breaks, no HTML, and no @mentions that would notify people.
    $clean -replace '\|', '\|' -replace '<', '&lt;' -replace '>', '&gt;' -replace '@', "@$([char] 0x200B)"
}

function ConvertTo-MtReviewMarkdown {
    <#
    .SYNOPSIS
    Writes the review results as the Markdown shown in the job summary and the pull request comment.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Result,
        [string] $Model
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('## Attribute review')
    $lines.Add('')
    if (-not $Result -or $Result.Count -eq 0) {
        $lines.Add('No test was added and no rubric attribute changed, so there was nothing to review.')
        return ($lines -join "`n")
    }
    $failed = @($Result | Where-Object Outcome -EQ 'Fail')
    $errored = @($Result | Where-Object Outcome -EQ 'Error')
    $passed = @($Result | Where-Object Outcome -EQ 'Pass')
    $lines.Add("Checked $($Result.Count) test(s) against the [attribute rubric](https://maester.dev/docs/writing-tests/attribute-rubric) with ``$Model``: $($passed.Count) passed, $($failed.Count) failed, $($errored.Count) could not be reviewed.")
    $lines.Add('')

    foreach ($item in $failed) {
        $lines.Add("### Fail: $(ConvertTo-MtReviewCell $item.Id)")
        $lines.Add('')
        $lines.Add("``$($item.Path)``")
        $lines.Add('')
        $lines.Add('| Attribute | Declared | Expected | Why |')
        $lines.Add('| --- | --- | --- | --- |')
        foreach ($finding in $item.Findings) {
            $lines.Add("| ``$(ConvertTo-MtReviewCell $finding.Attribute 40)`` | $(ConvertTo-MtReviewCell $finding.Declared 120) | $(ConvertTo-MtReviewCell $finding.Expected 120) | $(ConvertTo-MtReviewCell $finding.Reason) |")
        }
        $lines.Add('')
    }
    foreach ($item in $errored) {
        $lines.Add("### Not reviewed: $(ConvertTo-MtReviewCell $item.Id)")
        $lines.Add('')
        $lines.Add("``$($item.Path)``: $(ConvertTo-MtReviewCell $item.Error)")
        $lines.Add('')
    }
    if ($passed.Count -gt 0) {
        $lines.Add("### Pass")
        $lines.Add('')
        foreach ($item in $passed) { $lines.Add("- $(ConvertTo-MtReviewCell $item.Id): $($item.Reviewed -join ', ')") }
        $lines.Add('')
    }
    $notes = @($Result | Where-Object { $_.Notes.Count -gt 0 })
    if ($notes.Count -gt 0) {
        $lines.Add('### Notes')
        $lines.Add('')
        foreach ($item in $notes) {
            foreach ($note in $item.Notes) { $lines.Add("- $(ConvertTo-MtReviewCell $item.Id): $(ConvertTo-MtReviewCell $note)") }
        }
        $lines.Add('')
    }
    if ($failed.Count -gt 0) {
        $lines.Add('Change the value, or explain in the pull request why the declared value fits the rubric. A maintainer can overrule this check with the `attribute-review-override` label.')
    }
    $lines -join "`n"
}

function Invoke-MtAttributeReview {
    <#
    .SYNOPSIS
    Runs the review and returns the exit code.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string] $Root,
        [string] $HeadRoot,
        [string] $BaseRef,
        [string[]] $File,
        [string] $OutputPath,
        [string] $Model,
        [string] $Effort,
        [int] $MaxTests,
        [switch] $SkipWhenNoKey
    )

    if (-not $HeadRoot) { $HeadRoot = $Root }
    if (-not $File -and $BaseRef) {
        $File = @(& git -C $Root diff --name-only "$BaseRef...HEAD" -- tests) + @(& git -C $Root diff --name-only -- tests) |
            Where-Object { $_ } | Sort-Object -Unique
    }
    $null = New-Item -ItemType Directory -Path $OutputPath -Force
    $jsonPath = Join-Path $OutputPath 'attribute-review.json'
    $markdownPath = Join-Path $OutputPath 'attribute-review.md'

    $targets = @(Get-MtReviewTarget -Root $Root -HeadRoot $HeadRoot -BaseRef $BaseRef -File $File)
    if ($targets.Count -eq 0) {
        ConvertTo-MtReviewMarkdown -Result @() -Model $Model | Set-Content -LiteralPath $markdownPath -Encoding utf8
        '[]' | Set-Content -LiteralPath $jsonPath -Encoding utf8
        Write-Information 'Attribute review: nothing to review.' -InformationAction Continue
        return 0
    }

    $apiKey = $env:ANTHROPIC_API_KEY
    if (-not $apiKey) {
        $message = "Attribute review: ANTHROPIC_API_KEY is not set, so $($targets.Count) test(s) were not reviewed."
        "## Attribute review`n`n$message" | Set-Content -LiteralPath $markdownPath -Encoding utf8
        '[]' | Set-Content -LiteralPath $jsonPath -Encoding utf8
        Write-Warning $message
        return $(if ($SkipWhenNoKey) { 0 } else { 2 })
    }
    if ($targets.Count -gt $MaxTests) {
        $message = "Attribute review: $($targets.Count) tests need review, more than the limit of $MaxTests for one run. Split the change, or ask a maintainer to review the attributes and apply the attribute-review-override label."
        "## Attribute review`n`n$message" | Set-Content -LiteralPath $markdownPath -Encoding utf8
        '[]' | Set-Content -LiteralPath $jsonPath -Encoding utf8
        Write-Warning $message
        return 2
    }

    $system = Get-MtReviewSystem -Root $Root
    # The rubric's rule that the same check in two suites gets the same value needs the other tests in view.
    $index = @(Get-MtReviewIndex -Root $Root)
    foreach ($target in $targets) {
        if (-not $target.Error) { $target.Related = @(Get-MtReviewRelatedTest -Target $target -Index $index -Changed $targets) }
    }
    $results = foreach ($target in $targets) {
        if ($target.Error) {
            $failed = ConvertFrom-MtReviewResponse -Target $target -Response $null
            $failed.Error = $target.Error
            $failed
            continue
        }
        Write-Information "Attribute review: $($target.Id) ($($target.Changed -join ', '))" -InformationAction Continue
        try {
            $body = New-MtReviewRequestBody -Target $target -System $system -Model $Model -Effort $Effort
            $response = Invoke-MtReviewRequest -Body $body -ApiKey $apiKey
            ConvertFrom-MtReviewResponse -Target $target -Response $response
        } catch {
            $failed = ConvertFrom-MtReviewResponse -Target $target -Response $null
            $failed.Error = $_.Exception.Message
            $failed
        }
    }
    $results = @($results)

    $results | ConvertTo-Json -Depth 8 -AsArray | Set-Content -LiteralPath $jsonPath -Encoding utf8
    ConvertTo-MtReviewMarkdown -Result $results -Model $Model | Set-Content -LiteralPath $markdownPath -Encoding utf8

    if (@($results | Where-Object Outcome -EQ 'Error').Count -gt 0) { return 2 }
    if (@($results | Where-Object Outcome -EQ 'Fail').Count -gt 0) { return 1 }
    0
}

# Dot-sourcing the script loads its functions without running a review; the unit tests do this.
if ($MyInvocation.InvocationName -eq '.') { return }

$exitCode = Invoke-MtAttributeReview -Root $Root -HeadRoot $HeadRoot -BaseRef $BaseRef -File $File -OutputPath $OutputPath `
    -Model $Model -Effort $Effort -MaxTests $MaxTests -SkipWhenNoKey:$SkipWhenNoKey
exit $exitCode
