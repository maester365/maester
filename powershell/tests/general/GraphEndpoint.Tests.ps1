BeforeAll {
    $moduleRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $sourceFiles = @(
        Get-ChildItem -Path "$moduleRoot/public", "$moduleRoot/internal" -Recurse -File -Filter '*.ps1'
    )
    $globalGraphHostPattern = 'graph\.microsoft\.com'
}

Describe 'Microsoft Graph endpoints' {
    It 'does not hardcode the Global Graph endpoint in executable module code' {
        $violations = foreach ($sourceFile in $sourceFiles) {
            $tokens = $null
            $parseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $sourceFile.FullName,
                [ref] $tokens,
                [ref] $parseErrors
            ) | Out-Null

            if ($parseErrors) {
                throw "Failed to parse $($sourceFile.FullName)."
            }

            foreach ($token in $tokens) {
                if ($token.Kind -ne 'Comment' -and $token.Text -match $globalGraphHostPattern) {
                    $relativePath = $sourceFile.FullName.Substring($moduleRoot.Length + 1)
                    "${relativePath}:$($token.Extent.StartLineNumber): $($token.Text)"
                }
            }
        }

        $violations | Should -BeNullOrEmpty -Because (
            'Invoke-MgGraphRequest should use relative URIs so the connected cloud selects the endpoint: ' +
            ($violations -join ', ')
        )
    }
}
