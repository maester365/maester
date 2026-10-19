# Unit tests for build/review/Invoke-MtAttributeReview.ps1, the script behind the attribute-review workflow.
# No test here calls the Claude API: Invoke-WebRequest is mocked.

BeforeDiscovery {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

Describe 'Attribute review script' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        . (Join-Path $script:repoRoot 'build/review/Invoke-MtAttributeReview.ps1')

        function New-TestFileText {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Severity = 'High', [string] $Area = 'authentication', [string] $Body = '$true', [string] $Id = 'MT.9001', [string] $Feature = 'conditional-access')
            @"
function Test-MtReviewSample {
    [MaesterTest(
        Id = '$Id',
        Title = 'Sample',
        Product = 'entra',
        Feature = '$Feature',
        Area = '$Area',
        ResourceType = 'Tenant',
        Severity = '$Severity',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1110', 'T1078.004'),
        Service = 'Graph',
        Author = 'someone'
    )]
    [CmdletBinding()]
    param()
    $Body
}
"@
        }

        function New-ReviewTree {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Name)
            $root = Join-Path $TestDrive $Name
            $null = New-Item -ItemType Directory -Path (Join-Path $root 'tests/maester/entra') -Force
            $root
        }

        function New-ApiResponse {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Json, [string] $StopReason = 'end_turn')
            [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = (@{ model = 'claude-opus-5-5'; stop_reason = $StopReason; content = @(@{ type = 'text'; text = $Json }) } | ConvertTo-Json -Depth 6)
            }
        }

        $script:path = 'tests/maester/entra/Test.MT.9001.ps1'
    }

    Context 'Reading the attribute without running the file' {
        It 'Reads strings and lists' {
            $read = Get-MtReviewAttribute -Content (New-TestFileText)
            $read.Error | Should -BeNullOrEmpty
            $read.Attributes['Severity'] | Should -Be 'High'
            $read.Attributes['Mitre'] | Should -Be @('T1110', 'T1078.004')
        }

        It 'Does not execute code in the file' {
            $marker = Join-Path $TestDrive 'executed.txt'
            $text = (New-TestFileText) + "`nSet-Content -LiteralPath '$marker' -Value 'ran'"
            $null = Get-MtReviewAttribute -Content $text
            Test-Path $marker | Should -BeFalse
        }

        It 'Refuses a file with a using statement' {
            $read = Get-MtReviewAttribute -Content ("using module Something`n" + (New-TestFileText))
            $read.Error | Should -Match 'using statement'
        }

        It 'Reports a file with no attribute' {
            (Get-MtReviewAttribute -Content 'function Test-Nothing { }').Error | Should -Match 'No \[MaesterTest'
        }
    }

    Context 'Deciding what to review' {
        It 'Reviews every rubric attribute of a new test' {
            $root = New-ReviewTree 'new-root'
            $head = New-ReviewTree 'new-head'
            New-TestFileText | Set-Content (Join-Path $head $script:path)
            $targets = @(Get-MtReviewTarget -Root $root -HeadRoot $head -File $script:path)
            $targets.Count | Should -Be 1
            $targets[0].IsNew | Should -BeTrue
            $targets[0].Changed | Should -Contain 'Severity'
            $targets[0].Changed | Should -Contain 'Mitre'
            $targets[0].Id | Should -Be 'MT.9001'
        }

        It 'Reviews only the attributes that changed' {
            $root = New-ReviewTree 'changed-root'
            $head = New-ReviewTree 'changed-head'
            New-TestFileText -Severity 'High' | Set-Content (Join-Path $root $script:path)
            New-TestFileText -Severity 'Low' | Set-Content (Join-Path $head $script:path)
            $targets = @(Get-MtReviewTarget -Root $root -HeadRoot $head -File $script:path)
            $targets[0].IsNew | Should -BeFalse
            $targets[0].Changed | Should -Be @('Severity')
            $targets[0].Previous['Severity'] | Should -Be 'High'
        }

        It 'Skips a test whose code changed but whose rubric attributes did not' {
            $root = New-ReviewTree 'same-root'
            $head = New-ReviewTree 'same-head'
            New-TestFileText | Set-Content (Join-Path $root $script:path)
            New-TestFileText -Body '$false' | Set-Content (Join-Path $head $script:path)
            @(Get-MtReviewTarget -Root $root -HeadRoot $head -File $script:path).Count | Should -Be 0
        }

        It 'Skips a pull request that changed only the Markdown file' {
            $root = New-ReviewTree 'md-root'
            $head = New-ReviewTree 'md-head'
            New-TestFileText | Set-Content (Join-Path $root $script:path)
            'New text' | Set-Content (Join-Path $head ($script:path -replace '\.ps1$', '.md'))
            @(Get-MtReviewTarget -Root $root -HeadRoot $head -File ($script:path -replace '\.ps1$', '.md')).Count | Should -Be 0
        }

        It 'Ignores paths that are not test files and paths that climb out of the tree' {
            $root = New-ReviewTree 'paths-root'
            $head = New-ReviewTree 'paths-head'
            @(Get-MtReviewTarget -Root $root -HeadRoot $head -File 'README.md', 'tests/../secret/Test.X.ps1', 'src/Test.MT.1.ps1').Count | Should -Be 0
        }

        It 'Does not treat list order as a change' {
            (ConvertTo-MtReviewValue -Value @('T1110', 'T1078.004')) | Should -Be (ConvertTo-MtReviewValue -Value @('T1078.004', 'T1110'))
        }
    }

    Context 'The request' {
        BeforeAll {
            $script:system = Get-MtReviewSystem -Root $script:repoRoot
            $head = New-ReviewTree 'request-head'
            New-TestFileText | Set-Content (Join-Path $head $script:path)
            $script:target = @(Get-MtReviewTarget -Root (New-ReviewTree 'request-root') -HeadRoot $head -File $script:path)[0]
            $script:body = New-MtReviewRequestBody -Target $script:target -System $script:system -Model 'claude-opus-5-5' -Effort 'high'
        }

        It 'Sends the rubric and the taxonomy from the trusted root as a cached system block' {
            $script:system.Count | Should -Be 2
            $script:system[1].text | Should -Match 'Attribute rubric'
            $script:system[1].text | Should -Match 'conditional-access'
            $script:system[1].cache_control.type | Should -Be 'ephemeral'
        }

        It 'Asks for a schema-constrained answer and never forces a tool' {
            $script:body.output_config.format.type | Should -Be 'json_schema'
            $script:body.output_config.format.schema.additionalProperties | Should -BeFalse
            $script:body.output_config.effort | Should -Be 'high'
            $script:body.Contains('tool_choice') | Should -BeFalse
            $script:body.Contains('thinking') | Should -BeFalse
            $script:body.fallbacks | Should -Be 'default'
            $script:body.model | Should -Be 'claude-opus-5-5'
        }

        It 'Wraps the untrusted files in tags with a random suffix' {
            $content = $script:body.messages[0].content
            $content | Should -Match '<test_source_\d{9}>'
            $content | Should -Match 'attributes_to_review: Product'
        }

        It 'Serializes to valid JSON' {
            { $script:body | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30 } | Should -Not -Throw
        }
    }

    Context 'Related tests' {
        BeforeAll {
            $script:relatedRoot = New-ReviewTree 'related-root'
            $null = New-Item -ItemType Directory -Path (Join-Path $script:relatedRoot 'tests/cisa/entra') -Force
            New-TestFileText -Id 'CISA.X.1' -Severity 'High' | Set-Content (Join-Path $script:relatedRoot 'tests/cisa/entra/Test.CISA.X.1.ps1')
            New-TestFileText -Id 'CISA.X.2' -Feature 'authentication-methods' | Set-Content (Join-Path $script:relatedRoot 'tests/cisa/entra/Test.CISA.X.2.ps1')
            New-TestFileText -Severity 'Medium' | Set-Content (Join-Path $script:relatedRoot $script:path)
            $script:index = @(Get-MtReviewIndex -Root $script:relatedRoot)
            $head = New-ReviewTree 'related-head'
            New-TestFileText -Severity 'Medium' | Set-Content (Join-Path $head $script:path)
            $script:relatedTarget = @(Get-MtReviewTarget -Root (New-ReviewTree 'related-empty') -HeadRoot $head -File $script:path)[0]
        }

        It 'Reads every test under the root without running it' {
            $script:index.Id | Should -Contain 'CISA.X.1'
            ($script:index | Where-Object Id -EQ 'CISA.X.1').Severity | Should -Be 'High'
            ($script:index | Where-Object Id -EQ 'CISA.X.1').Title | Should -Be 'Sample'
        }

        It 'Lists only other tests with the same product and feature' {
            $related = @(Get-MtReviewRelatedTest -Target $script:relatedTarget -Index $script:index -Changed @($script:relatedTarget))
            $related.Id | Should -Be @('CISA.X.1')
            $related[0].Severity | Should -Be 'High'
            $related[0].Mitre | Should -Be 'T1078.004, T1110'
        }

        It 'Shows a test the pull request also changes with its new values' {
            $other = [pscustomobject]@{ Id = 'CISA.X.1'; Error = $null; Declared = [ordered]@{ Product = 'entra'; Feature = 'conditional-access'; Severity = 'Medium' } }
            $related = @(Get-MtReviewRelatedTest -Target $script:relatedTarget -Index $script:index -Changed @($script:relatedTarget, $other))
            $related[0].Severity | Should -Be 'Medium'
        }

        It 'Sends the related tests in the request, and none when there are none' {
            $script:relatedTarget.Related = @(Get-MtReviewRelatedTest -Target $script:relatedTarget -Index $script:index -Changed @())
            $body = New-MtReviewRequestBody -Target $script:relatedTarget -System @() -Model 'm' -Effort 'high'
            $body.messages[0].content | Should -Match 'related_tests: \[\{"Id":"CISA\.X\.1"'
            $script:relatedTarget.Related = @()
            $body = New-MtReviewRequestBody -Target $script:relatedTarget -System @() -Model 'm' -Effort 'high'
            $body.messages[0].content | Should -Match 'related_tests: none'
        }
    }

    Context 'Reading the answer' {
        BeforeAll {
            $head = New-ReviewTree 'answer-head'
            $root = New-ReviewTree 'answer-root'
            New-TestFileText -Severity 'High' | Set-Content (Join-Path $root $script:path)
            New-TestFileText -Severity 'Critical' | Set-Content (Join-Path $head $script:path)
            $script:changed = @(Get-MtReviewTarget -Root $root -HeadRoot $head -File $script:path)[0]
        }

        It 'Passes a clean review' {
            $response = [pscustomobject]@{ model = 'm'; stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = '{"verdict":"pass","findings":[],"notes":["ok"],"untrusted_instructions":false}' }) }
            $result = ConvertFrom-MtReviewResponse -Target $script:changed -Response $response
            $result.Outcome | Should -Be 'Pass'
            $result.Notes | Should -Contain 'ok'
        }

        It 'Fails on a finding for a reviewed attribute' {
            $response = [pscustomobject]@{ model = 'm'; stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = '{"verdict":"fail","findings":[{"attribute":"Severity","declared":"Critical","expected":"High","reason":"No direct path."}],"notes":[],"untrusted_instructions":false}' }) }
            $result = ConvertFrom-MtReviewResponse -Target $script:changed -Response $response
            $result.Outcome | Should -Be 'Fail'
            $result.Findings[0].Expected | Should -Be 'High'
        }

        It 'Fails when the model says pass but lists a finding' {
            $response = [pscustomobject]@{ model = 'm'; stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = '{"verdict":"pass","findings":[{"attribute":"Severity","declared":"Critical","expected":"High","reason":"x"}],"notes":[],"untrusted_instructions":false}' }) }
            (ConvertFrom-MtReviewResponse -Target $script:changed -Response $response).Outcome | Should -Be 'Fail'
        }

        It 'Turns a finding on an attribute that did not change into a note' {
            $response = [pscustomobject]@{ model = 'm'; stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = '{"verdict":"pass","findings":[{"attribute":"Area","declared":"authentication","expected":"access-control","reason":"x"}],"notes":[],"untrusted_instructions":false}' }) }
            $result = ConvertFrom-MtReviewResponse -Target $script:changed -Response $response
            $result.Outcome | Should -Be 'Pass'
            $result.Notes[0] | Should -Match '^Area'
        }

        It 'Fails when the files try to steer the reviewer' {
            $response = [pscustomobject]@{ model = 'm'; stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = '{"verdict":"pass","findings":[],"notes":[],"untrusted_instructions":true}' }) }
            (ConvertFrom-MtReviewResponse -Target $script:changed -Response $response).Outcome | Should -Be 'Fail'
        }

        It 'Reports a refusal and a cut-off answer as errors, not passes' {
            foreach ($reason in 'refusal', 'max_tokens') {
                $response = [pscustomobject]@{ model = 'm'; stop_reason = $reason; content = @() }
                (ConvertFrom-MtReviewResponse -Target $script:changed -Response $response).Outcome | Should -Be 'Error'
            }
        }

        It 'Reports an unreadable answer as an error' {
            $response = [pscustomobject]@{ model = 'm'; stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = 'not json' }) }
            (ConvertFrom-MtReviewResponse -Target $script:changed -Response $response).Outcome | Should -Be 'Error'
        }
    }

    Context 'The report' {
        It 'Escapes model text so it cannot break the table, add HTML or mention people' {
            $cell = ConvertTo-MtReviewCell -Text "a | b <img src=x> @maintainer`nnext"
            $cell | Should -Not -Match '(?<!\\)\|'
            $cell | Should -Not -Match '<img'
            $cell | Should -Not -Match '@maintainer'
            $cell | Should -Not -Match "`n"
        }

        It 'Says so when there was nothing to review' {
            ConvertTo-MtReviewMarkdown -Result @() -Model 'm' | Should -Match 'nothing to review'
        }
    }

    Context 'End to end with a mocked API' {
        BeforeEach {
            $script:savedKey = $env:ANTHROPIC_API_KEY
            $script:root = New-ReviewTree "e2e-root-$([guid]::NewGuid().ToString('N'))"
            $script:head = New-ReviewTree "e2e-head-$([guid]::NewGuid().ToString('N'))"
            foreach ($relative in 'build/review/attribute-review-prompt.md', 'website/docs/writing-tests/attribute-rubric.md', 'powershell/assets/MaesterTaxonomy.psd1') {
                $destination = Join-Path $script:root $relative
                $null = New-Item -ItemType Directory -Path (Split-Path $destination) -Force
                Copy-Item (Join-Path $script:repoRoot $relative) $destination
            }
            New-TestFileText | Set-Content (Join-Path $script:head $script:path)
            $script:out = Join-Path $TestDrive "out-$([guid]::NewGuid().ToString('N'))"
            $script:arguments = @{ Root = $script:root; HeadRoot = $script:head; File = $script:path; OutputPath = $script:out; Model = 'claude-opus-5-5'; Effort = 'high'; MaxTests = 25 }
        }
        AfterEach { $env:ANTHROPIC_API_KEY = $script:savedKey }

        It 'Returns 0 and writes both reports when the review passes' {
            $env:ANTHROPIC_API_KEY = 'test-key'
            Mock Invoke-WebRequest { New-ApiResponse -Json '{"verdict":"pass","findings":[],"notes":[],"untrusted_instructions":false}' }
            Invoke-MtAttributeReview @script:arguments | Should -Be 0
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://api.anthropic.com/v1/messages' -and $Headers['x-api-key'] -eq 'test-key' -and
                $Headers['anthropic-version'] -eq '2023-06-01' -and $Headers['anthropic-beta'] -eq 'server-side-fallback-2026-07-01'
            }
            Get-Content (Join-Path $script:out 'attribute-review.md') -Raw | Should -Match '1 passed'
            (Get-Content (Join-Path $script:out 'attribute-review.json') -Raw | ConvertFrom-Json)[0].Outcome | Should -Be 'Pass'
        }

        It 'Returns 1 when an attribute does not fit the rubric' {
            $env:ANTHROPIC_API_KEY = 'test-key'
            Mock Invoke-WebRequest { New-ApiResponse -Json '{"verdict":"fail","findings":[{"attribute":"Area","declared":"authentication","expected":"access-control","reason":"Device condition."}],"notes":[],"untrusted_instructions":false}' }
            Invoke-MtAttributeReview @script:arguments | Should -Be 1
            Get-Content (Join-Path $script:out 'attribute-review.md') -Raw | Should -Match 'access-control'
        }

        It 'Returns 2 when the API fails for good, without retrying a request error' {
            $env:ANTHROPIC_API_KEY = 'test-key'
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 400; Headers = @{}; Content = '{"error":{"type":"invalid_request_error","message":"bad"}}' } }
            Invoke-MtAttributeReview @script:arguments | Should -Be 2
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            Get-Content (Join-Path $script:out 'attribute-review.md') -Raw | Should -Match 'invalid_request_error'
        }

        It 'Retries a rate limit and then succeeds' {
            $env:ANTHROPIC_API_KEY = 'test-key'
            $script:calls = 0
            Mock Start-Sleep { }
            Mock Invoke-WebRequest {
                $script:calls++
                if ($script:calls -eq 1) { [pscustomobject]@{ StatusCode = 429; Headers = @{ 'retry-after' = @('1') }; Content = '{"error":{"type":"rate_limit_error","message":"slow down"}}' } }
                else { New-ApiResponse -Json '{"verdict":"pass","findings":[],"notes":[],"untrusted_instructions":false}' }
            }
            Invoke-MtAttributeReview @script:arguments | Should -Be 0
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
        }

        It 'Never calls the API without a key: 2 by default, 0 when asked to skip' {
            $env:ANTHROPIC_API_KEY = $null
            Mock Invoke-WebRequest { throw 'must not be called' }
            Invoke-MtAttributeReview @script:arguments 3>$null | Should -Be 2
            Invoke-MtAttributeReview @script:arguments -SkipWhenNoKey 3>$null | Should -Be 0
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        }

        It 'Returns 2 without calling the API when too many tests need review' {
            $env:ANTHROPIC_API_KEY = 'test-key'
            Mock Invoke-WebRequest { throw 'must not be called' }
            $script:arguments.MaxTests = 1
            New-TestFileText | Set-Content (Join-Path $script:head 'tests/maester/entra/Test.MT.9002.ps1')
            $script:arguments.File = @($script:path, 'tests/maester/entra/Test.MT.9002.ps1')
            Invoke-MtAttributeReview @script:arguments 3>$null | Should -Be 2
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        }

        It 'Returns 0 with no API call when nothing needs review' {
            $env:ANTHROPIC_API_KEY = 'test-key'
            Mock Invoke-WebRequest { throw 'must not be called' }
            $script:arguments.File = @('README.md')
            Invoke-MtAttributeReview @script:arguments | Should -Be 0
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        }
    }
}
