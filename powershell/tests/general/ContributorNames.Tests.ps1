# Guards the names in the contributor registry (website/contributors/contributors.yml), which maester.dev shows on
# /contributors and in the byline of every test page. A name is written as the person writes it: each word starts
# with a capital letter, except the particles inside a name ("Robbe Van den Daele", "Stephan van Rooij"), and a
# name that is the person's GitHub handle is written as the handle is.
# A name taken from git when the registry has none is capitalized by website/scripts/contributors.mjs instead.
BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $registry = Join-Path $repoRoot 'website/contributors/contributors.yml'
    $script:Names = @(
        $handle = $null
        foreach ($line in Get-Content -LiteralPath $registry) {
            if ($line -match '^([^\s#][^:]*):\s*$') { $handle = $Matches[1]; continue }
            # The value without a comment after it: a quoted value as quoted, else up to ' #'.
            if ($handle -and $line -match '^  name:\s*(?:"(?<q>[^"]*)"|''(?<q>[^'']*)''|(?<q>.+?))\s*(?:\s#.*)?$') {
                @{ Handle = $handle; Name = $Matches.q.Trim() }
            }
        }
    )
}

Describe 'Contributor registry' {
    BeforeAll {
        # The same list as nameParticles in website/scripts/contributors.mjs.
        $script:Particles = @('van', 'von', 'der', 'den', 'de', 'del', 'della', 'di', 'da', 'dos', 'du', 'la', 'le', 'bin', 'ibn', 'al', 'el', 'ter', 'ten', 'zu')
    }

    It 'knows the same particles as the site''s generator' {
        $script_ = Get-Content -LiteralPath (Join-Path "$PSScriptRoot/../../.." 'website/scripts/contributors.mjs') -Raw
        $list = [regex]::Match($script_, 'nameParticles = new Set\(\[([^\]]*)\]\)').Groups[1].Value
        $generator = @([regex]::Matches($list, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        ($generator -join ',') | Should -Be ($script:Particles -join ',')
    }

    It 'has names to check' -ForEach @(@{ Count = $script:Names.Count }) {
        $Count | Should -BeGreaterThan 10
    }

    It 'capitalizes the name of <Handle>: <Name>' -ForEach $script:Names {
        # A contributor who goes by their GitHub handle writes it as GitHub has it.
        if ($Name -ieq $Handle) { return }
        $words = @($Name -split '\s+' | Where-Object { $_ })
        $lower = for ($i = 0; $i -lt $words.Count; $i++) {
            $word = $words[$i]
            $first = [regex]::Match($word, '\p{L}')
            if (-not $first.Success) { continue }
            if ($i -gt 0 -and $i -lt $words.Count - 1 -and $word -cin $script:Particles) { continue }
            if ([char]::IsLower($first.Value, 0)) { $word }
        }
        @($lower) | Should -BeNullOrEmpty -Because "each word of a name starts with a capital letter, except a particle such as 'van' or 'den' inside it (a last word is a surname)"
    }
}
