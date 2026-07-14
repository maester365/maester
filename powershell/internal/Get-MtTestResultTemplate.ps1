function Get-MtTestResultTemplate {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]] $CommandName,

        [Parameter()]
        [string] $TestId,

        [Parameter()]
        [string] $SourceFile
    )

    $candidateNames = [System.Collections.Generic.List[string]]::new()

    # EIDSCA tests use one public dispatcher, so their implementation command is
    # derived from the control ID rather than appearing directly in the test body.
    if ($TestId -match '^EIDSCA\.(.+)$') {
        $candidateNames.Add("Test-MtEidsca$($Matches[1])")
    }

    foreach ($name in $CommandName) {
        if ($name -and -not $candidateNames.Contains($name)) {
            $candidateNames.Add($name)
        }
    }

    $metadataCache = Get-Variable -Name MtTestMetadataCache -Scope Script -ErrorAction SilentlyContinue
    if (-not $metadataCache) {
        $script:MtTestMetadataCache = $false
        $moduleBase = $MyInvocation.MyCommand.Module.ModuleBase
        if ($moduleBase) {
            $metadataPath = Join-Path $moduleBase 'Maester.TestMetadata.json'
            if (Test-Path -LiteralPath $metadataPath) {
                try {
                    $script:MtTestMetadataCache = Get-Content -LiteralPath $metadataPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-Warning "Failed to read test metadata bundle: $($_.Exception.Message)"
                }
            }
        }
    }

    foreach ($name in $candidateNames) {
        if ($script:MtTestMetadataCache) {
            $metadataProperty = $script:MtTestMetadataCache.PSObject.Properties[$name]
            if ($metadataProperty) {
                return [PSCustomObject]@{
                    CommandName = $name
                    Description = $metadataProperty.Value.Description
                    Result = $metadataProperty.Value.Result
                }
            }
        }

        # Source checkouts do not have the generated JSON bundle. Resolve the
        # authored function file and load its adjacent Markdown instead.
        $command = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
        $scriptPath = $command.ScriptBlock.File
        if ($scriptPath -and [System.IO.Path]::GetExtension($scriptPath) -eq '.ps1') {
            $markdownPath = [System.IO.Path]::ChangeExtension($scriptPath, '.md')
            if (Test-Path -LiteralPath $markdownPath) {
                try {
                    $content = Get-Content -LiteralPath $markdownPath -Raw -ErrorAction Stop
                    $splitContent = $content -split '<!--- Results --->', 2
                    return [PSCustomObject]@{
                        CommandName = $name
                        Description = $splitContent[0]
                        Result = if ($splitContent.Count -gt 1) { $splitContent[1] } else { $null }
                    }
                } catch {
                    Write-Warning "Failed to read markdown file '$markdownPath': $($_.Exception.Message)"
                }
            }
        }
    }

    if ($SourceFile -and [System.IO.Path]::GetExtension($SourceFile) -eq '.ps1') {
        $markdownPath = [System.IO.Path]::ChangeExtension($SourceFile, '.md')
        if (Test-Path -LiteralPath $markdownPath) {
            try {
                $content = Get-Content -LiteralPath $markdownPath -Raw -ErrorAction Stop
                $splitContent = $content -split '<!--- Results --->', 2
                return [PSCustomObject]@{
                    CommandName = $null
                    Description = $splitContent[0]
                    Result = if ($splitContent.Count -gt 1) { $splitContent[1] } else { $null }
                }
            } catch {
                Write-Warning "Failed to read markdown file '$markdownPath': $($_.Exception.Message)"
            }
        }
    }

    return $null
}
