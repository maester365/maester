Describe 'Microsoft Graph endpoints' {
    It 'does not hardcode the Global Graph endpoint outside approved fallbacks' {
        $moduleRoot = (Resolve-Path "$PSScriptRoot/../..").Path
        $sourceFiles = @(
            Get-ChildItem -Path "$moduleRoot/public", "$moduleRoot/internal" -Recurse -File -Filter '*.ps1'
        )
        $globalGraphHostPattern = 'graph\.microsoft\.com'

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
                    $relativePath = $sourceFile.FullName.Substring($moduleRoot.Length + 1) -replace '\\', '/'

                    # Invoke-MtAzureRequest uses Invoke-AzRest, which requires an absolute URI.
                    # Keep its public-cloud fallback when the Azure context has no MicrosoftGraphUrl.
                    $isApprovedFallback = (
                        $relativePath -eq 'public/core/Invoke-MtAzureRequest.ps1' -and
                        $token.Text -eq "'https://graph.microsoft.com'"
                    )

                    if (-not $isApprovedFallback) {
                        "${relativePath}:$($token.Extent.StartLineNumber): $($token.Text)"
                    }
                }
            }
        }

        $violations | Should -BeNullOrEmpty -Because (
            'Invoke-MgGraphRequest should use relative URIs; only documented non-SDK fallbacks may hardcode the Global endpoint: ' +
            ($violations -join ', ')
        )
    }
}
