function Get-MtPackCandidate {
    <#
    .SYNOPSIS
    Fetches a pack into a staging folder and validates it, without running any of it (Maester Packs design, sections 5.1 to 5.4).

    .DESCRIPTION
    GitHub: resolves the source to a commit of the named repository (Resolve-MtPackGitHubSource), downloads
    that commit's archive and extracts it safely (Expand-MtPackArchive). A local folder is copied. A pack
    that ships with Maester is read where it is.

    The staged copy is then validated and scanned (Test-MtPackContent). For a GitHub pack the manifest's
    publisher must be the repository's owner, so a pack cannot claim someone else's name; packs from the
    maester365 organisation may use the official names.

    Returns the candidate: Kind, Id, Manifest, Root (the staged folder), Digest, TestIds, Tests, Risk,
    Findings, Binaries, Errors, Warnings, Source (the text recorded in config and lock), the GitHub fields
    (Owner, Repo, Folder, RepositoryId, OwnerId, Ref, Commit, Release, AgeHours, AgeSource, CooldownMet,
    Newer, UsedToken, Archived) and Staging (a folder the caller removes, or $null).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter()] [string] $Version,
        [Parameter()] [switch] $IncludeRecent,
        [Parameter()] [int] $CooldownHours = 72,
        [Parameter()] [string[]] $RequiredService = @(),
        # Fetch exactly this commit (Restore-MtPack), skipping release selection.
        [Parameter()] [string] $Commit,
        # The branch or tag the commit was installed from (the lock file's Ref), which it may be reachable from.
        [Parameter()] [string] $CommitRef
    )

    # Staging is only a temporary copy to read, so it happens under -WhatIf too.
    $WhatIfPreference = $false
    $parsed = ConvertFrom-MtPackSource -Source $Source
    $candidate = [ordered]@{
        Kind = $parsed.Kind; Source = $parsed.Display; Owner = $parsed.Owner; Repo = $parsed.Repo; Folder = $parsed.Folder; Path = $parsed.Path
        RepositoryId = $null; OwnerId = $null; Ref = $null; Commit = $null; Release = $null; AgeHours = $null; AgeSource = $null
        CooldownHours = $CooldownHours; CooldownMet = $true; Newer = $null; UsedToken = $false; Archived = $false; Staging = $null
    }

    switch ($parsed.Kind) {
        'BuiltIn' { $root = $parsed.Path; $official = $true }
        'Local' {
            $staging = Join-Path ([System.IO.Path]::GetTempPath()) "maester-pack-$([guid]::NewGuid().ToString('n'))"
            $candidate.Staging = $staging
            $null = New-Item -Path $staging -ItemType Directory -Force
            Get-ChildItem -LiteralPath $parsed.Path -Force | Where-Object Name -NE '.git' | Copy-Item -Destination $staging -Recurse -Force
            $root = $staging
            $official = $false
        }
        'GitHub' {
            if ($Commit) { $parsed.Ref = $Commit }
            $resolved = Resolve-MtPackGitHubSource -Source $parsed -Version $Version -IncludeRecent:$IncludeRecent -CooldownHours $CooldownHours -ReachableFrom @($CommitRef | Where-Object { $_ })
            foreach ($p in $resolved.PSObject.Properties) { if ($candidate.Contains($p.Name)) { $candidate[$p.Name] = $p.Value } }
            $candidate.Source = "github.com/$($resolved.Owner)/$($resolved.Repo)$(if ($resolved.Folder) { "/$($resolved.Folder)" })"
            $staging = Join-Path ([System.IO.Path]::GetTempPath()) "maester-pack-$([guid]::NewGuid().ToString('n'))"
            $candidate.Staging = $staging
            $null = New-Item -Path $staging -ItemType Directory -Force
            $archive = Join-Path $staging 'archive.zip'
            $null = Invoke-MtPackGitHubRequest -Path "repos/$($resolved.Owner)/$($resolved.Repo)/zipball/$($resolved.Commit)" -OutFile $archive
            $root = Join-Path $staging 'pack'
            Expand-MtPackArchive -Archive $archive -Destination $root -Folder $resolved.Folder
            Remove-Item -LiteralPath $archive -Force
            $official = $resolved.OwnerLogin -eq 'maester365'
        }
    }

    $content = Test-MtPackContent -Path $root -Official:$official -RequiredService $RequiredService
    $errors = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($e in $content.Errors) { $errors.Add($e) }
    if ($parsed.Kind -eq 'GitHub' -and $content.Manifest -and $content.Manifest.Publisher -and $content.Manifest.Publisher -ne $candidate.Owner -and $content.Manifest.Publisher.ToLowerInvariant() -ne ([string]$candidate.Owner).ToLowerInvariant()) {
        $errors.Add([pscustomobject]@{ Code = 'PublisherMismatch'; Message = "The pack says its publisher is '$($content.Manifest.Publisher)', but it comes from the GitHub account '$($candidate.Owner)'. A pack's publisher must be the owner of its repository." })
    }

    $candidate.Id = if ($content.Manifest) { [string]$content.Manifest.Id } else { $null }
    $candidate.Manifest = $content.Manifest
    $candidate.Root = $root
    $candidate.Digest = $content.Digest
    $candidate.TestIds = @($content.TestIds)
    $candidate.Tests = @($content.Tests)
    $candidate.Risk = $content.Risk
    $candidate.Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($f in $content.Findings) { $candidate.Findings.Add($f) }
    $candidate.Binaries = @($content.Binaries)
    $candidate.Errors = $errors.ToArray()
    $candidate.Warnings = @($content.Warnings)
    $candidate.Official = $official
    $candidate.Modules = @()
    [pscustomobject]$candidate
}
