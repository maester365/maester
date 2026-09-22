[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingInvokeExpression',
    '',
    Justification = 'The test evaluates two function ASTs from the script without executing its orchestration body.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'A fixed test-only value validates in-memory named-pipe transport and is never persisted.'
)]
param()

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot 'Rerun-Plan1-Under-Plan9.ps1'
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw ($parseErrors.Message -join [Environment]::NewLine)
    }

    foreach ($functionName in @('Get-JsonArtifact', 'Get-ComparisonStatus')) {
        $functionAst = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName
        }, $true)
        Invoke-Expression $functionAst.Extent.Text
    }
}

Describe 'Rerun-Plan1-Under-Plan9 failure reporting' {
    It 'returns an empty array rather than null when no artifacts exist' {
        $result = Get-JsonArtifact -Path (Join-Path $TestDrive 'missing') -Filter '*.json'

        $null -eq $result | Should -BeFalse
        @($result).Count | Should -Be 0
    }

    It 'classifies a failed mandatory prerequisite before E2E as blocked' {
        $preflight = [PSCustomObject]@{
            OverallSuccess = $false
            Checks = @([PSCustomObject]@{
                CheckId = 'DNS.Win.DC03'
                Mandatory = $true
                Success = $false
            })
        }

        $result = Get-ComparisonStatus -Scenario 'Cross-domain targeting' `
            -ProtocolRowIds @() -PublicRowIds @() -ProtocolRows @() -PublicRows @() `
            -Preflight $preflight -ProtocolGateStatus 'NOT_RUN'

        $result.NewStatus | Should -Be 'BLOCKED_BY_PREFLIGHT'
        $result.RootCause | Should -Be 'DNS.Win.DC03'
    }

    It 'reports missing mandatory public rows as a process failure' {
        $preflight = [PSCustomObject]@{ OverallSuccess = $true; Checks = @() }
        $protocolRows = @([PSCustomObject]@{ ProbeId = 'probe-1'; ExpectationMet = $true })

        $result = Get-ComparisonStatus -Scenario 'Cross-domain targeting' `
            -ProtocolRowIds @('probe-1') -PublicRowIds @('public-1') `
            -ProtocolRows $protocolRows -PublicRows @() -Preflight $preflight `
            -ProtocolGateStatus 'PASS'

        $result.NewStatus | Should -Be 'FAIL'
        $result.RootCause | Should -Be 'Mandatory public rows missing: public-1'
    }

    It 'allows protocol-only StartTLS evidence to pass without public rows' {
        $preflight = [PSCustomObject]@{ OverallSuccess = $true; Checks = @() }
        $protocolRows = @([PSCustomObject]@{ ProbeId = 'starttls-1'; ExpectationMet = $true })

        $result = Get-ComparisonStatus -Scenario 'StartTLS negotiation' `
            -ProtocolRowIds @('starttls-1') -PublicRowIds @() `
            -ProtocolRows $protocolRows -PublicRows @() -Preflight $preflight `
            -ProtocolGateStatus 'PASS'

        $result.NewStatus | Should -Be 'PASS'
    }
}

Describe 'Rerun-Plan1-Under-Plan9 credential bridge' {
    It 'uses current-user-only named pipes and never writes credential CLIXML' {
        $content = Get-Content -LiteralPath $scriptPath -Raw

        $content | Should -Match 'PipeOptions\]::CurrentUserOnly'
        $content | Should -Not -Match 'Export-Clixml'
        $content | Should -Match 'ProcessStartInfo'
    }

    It 'round-trips a credential through a current-user-only child-process pipe' {
        $pipeName = "maester-plan1-test-$([guid]::NewGuid())"
        $launcher = Join-Path $TestDrive 'pipe-reader.ps1'
        $resultPath = Join-Path $TestDrive 'pipe-result.txt'
        [System.IO.File]::WriteAllText($launcher, @'
param($PipeName, $ResultPath)
$client = [System.IO.Pipes.NamedPipeClientStream]::new(
    '.', $PipeName, [System.IO.Pipes.PipeDirection]::In,
    [System.IO.Pipes.PipeOptions]::CurrentUserOnly
)
try {
    $client.Connect(30000)
    $reader = [System.IO.StreamReader]::new($client)
    try {
        $data = [System.Management.Automation.PSSerializer]::Deserialize($reader.ReadToEnd())
    }
    finally {
        $reader.Dispose()
    }
}
finally {
    $client.Dispose()
}
[System.IO.File]::WriteAllText($ResultPath, $data.Root.UserName)
'@)

        $server = [System.IO.Pipes.NamedPipeServerStream]::new(
            $pipeName,
            [System.IO.Pipes.PipeDirection]::Out,
            1,
            [System.IO.Pipes.PipeTransmissionMode]::Byte,
            [System.IO.Pipes.PipeOptions]::Asynchronous -bor [System.IO.Pipes.PipeOptions]::CurrentUserOnly
        )
        $process = $null
        try {
            $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
            $startInfo.UseShellExecute = $false
            foreach ($argument in @('-NoProfile', '-File', $launcher, '-PipeName', $pipeName, '-ResultPath', $resultPath)) {
                $startInfo.ArgumentList.Add($argument)
            }
            $process = [System.Diagnostics.Process]::Start($startInfo)
            $server.WaitForConnectionAsync().Wait([timespan]::FromSeconds(30)) | Should -BeTrue
            $writer = [System.IO.StreamWriter]::new($server)
            $password = ConvertTo-SecureString 'test-only' -AsPlainText -Force
            $payload = [System.Management.Automation.PSSerializer]::Serialize([PSCustomObject]@{
                Root = [PSCredential]::new('MISOULE02\reader', $password)
            }, 4)
            $writer.Write($payload)
            $writer.Dispose()
            $process.WaitForExit(30000) | Should -BeTrue
            $process.ExitCode | Should -Be 0
            [System.IO.File]::ReadAllText($resultPath) | Should -Be 'MISOULE02\reader'
        }
        finally {
            $server.Dispose()
            if ($null -ne $process) { $process.Dispose() }
        }
    }
}
