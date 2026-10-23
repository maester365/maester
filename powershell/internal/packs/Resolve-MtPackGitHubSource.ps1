function Resolve-MtPackGitHubSource {
    <#
    .SYNOPSIS
    Resolves a GitHub pack source to one commit of the named repository, and how old that content is (Maester Packs design, sections 5.4 and 5.7).

    .DESCRIPTION
    Reads the repository (its numeric ID and owner ID, which the lock file and policy key on), then picks
    the commit:

    - @<commit>: that commit, which must be reachable from the default branch or a release tag of the
      repository itself. GitHub serves any commit of a fork under the original's name, so this stops a
      fork's commit from installing with the original's name and badges.
    - @<tag or branch>, or -Version (a release tag, with or without a leading v): that ref.
    - Otherwise the newest release, not a draft or prerelease, that is older than the cooldown; a newer
      one is returned in Newer and needs -IncludeRecent. Without any release, the default branch.

    The cooldown is measured on the content, never on a date a publisher can set: the release's
    published_at time counts only for a GitHub immutable release, whose tag cannot be moved. For any other
    ref the clock is when this computer first saw that commit of that repository (seen.json), so a tag
    moved to a new commit starts a new cooldown. Every commit resolved here is recorded as seen.

    Returns Owner, Repo, Folder, RepositoryId, OwnerId, OwnerLogin, Private, Archived, Ref, Commit,
    Release (TagName, PublishedAt, Immutable or $null), AgeHours, AgeSource (ImmutableRelease or
    FirstSeen), CooldownHours, CooldownMet, Newer (a newer release left out by the cooldown, or $null)
    and UsedToken.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Source,
        # A release version, such as 1.2.0 or v1.2.0.
        [Parameter()] [string] $Version,
        [Parameter()] [switch] $IncludeRecent,
        [Parameter()] [int] $CooldownHours = 72
    )

    $usedToken = $false
    $repoPath = "repos/$($Source.Owner)/$($Source.Repo)"
    $repository = Invoke-MtPackGitHubRequest -Path $repoPath -UsedToken ([ref] $usedToken)
    $owner = $Source.Owner
    $repo = $Source.Repo
    if ($repository.full_name -and $repository.full_name -ne "$owner/$repo") {
        # GitHub follows renames and transfers; the lock and the prompt use the current name.
        Write-Warning "The repository $owner/$repo is now $($repository.full_name)."
        $owner, $repo = $repository.full_name.Split('/')
        $repoPath = "repos/$owner/$repo"
    }

    $releases = @(Invoke-MtPackGitHubRequest -Path "$repoPath/releases?per_page=30" | Where-Object { -not $_.draft -and -not $_.prerelease } |
            Sort-Object { [datetime]$_.published_at } -Descending)
    $commitOf = {
        param($ref)
        $commit = Invoke-MtPackGitHubRequest -Path "$repoPath/commits/$([uri]::EscapeDataString($ref))"
        [string]$commit.sha
    }
    $ageOf = {
        param($release, $commit)
        if ($release -and $release.PSObject.Properties['immutable'] -and $release.immutable -eq $true -and $release.published_at) {
            return [pscustomobject]@{ Hours = ([datetime]::UtcNow - ([datetime]$release.published_at).ToUniversalTime()).TotalHours; Source = 'ImmutableRelease' }
        }
        $seen = Get-MtPackFirstSeen -RepositoryId $repository.id -Commit $commit
        [pscustomobject]@{ Hours = ([datetime]::UtcNow - $seen).TotalHours; Source = 'FirstSeen' }
    }

    $requested = if ($Source.Ref) { $Source.Ref } elseif ($Version) { $Version } else { $null }
    $release = $null
    $newer = $null
    if ($requested) {
        $release = $releases | Where-Object { $_.tag_name -eq $requested -or $_.tag_name -eq "v$requested" -or "v$($_.tag_name)" -eq $requested } | Select-Object -First 1
        if (-not $release) { $release = Invoke-MtPackGitHubRequest -Path "$repoPath/releases/tags/$([uri]::EscapeDataString($requested))" -AllowNotFound }
        $ref = if ($release) { [string]$release.tag_name } else { $requested }
        if ($release) { $commit = & $commitOf "refs/tags/$ref" }
        else {
            # The commits API also accepts SHA aliases and expressions. Only real repository refs
            # may bypass the default-branch/release reachability rule for explicit commits.
            $Names = if ($requested.StartsWith('refs/heads/') -or $requested.StartsWith('refs/tags/')) {
                @($requested.Substring(5))
            } else { @("heads/$requested", "tags/$requested") }
            $NamedRef = $null
            foreach ($Name in $Names) {
                $CandidateRef = Invoke-MtPackGitHubRequest -Path "$repoPath/git/ref/$([uri]::EscapeDataString($Name))" -AllowNotFound
                if ($CandidateRef -and $CandidateRef.ref -ceq "refs/$Name") { $NamedRef = $CandidateRef; break }
            }
            if ($NamedRef) { $commit = & $commitOf ([string]$NamedRef.ref) }
            elseif ($requested -match '^[0-9a-f]{1,40}$') {
                # Hexadecimal branch/tag names are legitimate; only an input without a real ref is a SHA alias.
                $commit = & $commitOf $requested
                $refs = @($repository.default_branch) + @($releases | ForEach-Object { "refs/tags/$($_.tag_name)" })
                if (-not (Test-MtPackCommitReachable -RepositoryPath $repoPath -Commit $commit -Ref $refs)) {
                    throw "The commit $commit is not on the default branch or a release of $owner/$repo. GitHub serves commits from forks under the original repository's name, so Maester installs only commits that belong to the repository itself."
                }
                $release = $releases | Where-Object { $_.target_commitish -eq $commit } | Select-Object -First 1
                $ref = $commit
            }
            else { throw "'$requested' is not a branch or tag of $owner/$repo. Use a reachable commit ID instead." }
        }
    } elseif ($releases.Count -gt 0) {
        $chosen = $null
        foreach ($candidate in $releases) {
            $candidateCommit = & $commitOf "refs/tags/$($candidate.tag_name)"
            $age = & $ageOf $candidate $candidateCommit
            if ($IncludeRecent -or $age.Hours -ge $CooldownHours) { $chosen = [pscustomobject]@{ Release = $candidate; Commit = $candidateCommit }; break }
            if (-not $newer) { $newer = [pscustomobject]@{ TagName = [string]$candidate.tag_name; Commit = $candidateCommit; AgeHours = [math]::Round($age.Hours, 1); AgeSource = $age.Source } }
        }
        if (-not $chosen) {
            # Every release is newer than the cooldown: offer the newest, which then needs -IncludeRecent.
            $chosen = [pscustomobject]@{ Release = $releases[0]; Commit = $newer.Commit }
            $newer = $null
        }
        $release = $chosen.Release
        $ref = [string]$release.tag_name
        $commit = $chosen.Commit
    } else {
        $ref = [string]$repository.default_branch
        $commit = & $commitOf $ref
    }

    $age = & $ageOf $release $commit
    [pscustomobject]@{
        Owner         = $owner
        Repo          = $repo
        Folder        = $Source.Folder
        RepositoryId  = [long]$repository.id
        OwnerId       = [long]$repository.owner.id
        OwnerLogin    = [string]$repository.owner.login
        Private       = [bool]$repository.private
        Archived      = [bool]$repository.archived
        Ref           = $ref
        Commit        = $commit
        Release       = if ($release) { [pscustomobject]@{ TagName = [string]$release.tag_name; PublishedAt = $(if ($release.published_at -is [datetime]) { $release.published_at.ToUniversalTime().ToString('o', [cultureinfo]::InvariantCulture) } else { [string]$release.published_at }); Immutable = [bool]($release.PSObject.Properties['immutable'] -and $release.immutable) } } else { $null }
        AgeHours      = [math]::Round($age.Hours, 1)
        AgeSource     = $age.Source
        CooldownHours = $CooldownHours
        CooldownMet   = $age.Hours -ge $CooldownHours
        Newer         = $newer
        UsedToken     = $usedToken
    }
}

function Test-MtPackCommitReachable {
    <#
    .SYNOPSIS
    True when a commit is reachable from one of the given refs of a repository, through GitHub's compare API.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $RepositoryPath,
        [Parameter(Mandatory)] [string] $Commit,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Ref
    )

    foreach ($r in ($Ref | Where-Object { $_ } | Select-Object -Unique -First 10)) {
        $compare = Invoke-MtPackGitHubRequest -Path "$RepositoryPath/compare/$([uri]::EscapeDataString($r))...$Commit" -AllowNotFound
        # 'behind' or 'identical': the commit is an ancestor of the ref, or is the ref.
        if ($compare -and $compare.status -in 'behind', 'identical') { return $true }
    }
    $false
}

function Get-MtPackFirstSeen {
    <#
    .SYNOPSIS
    Returns when this computer first saw a commit of a repository (UTC), recording now when it is new.

    .DESCRIPTION
    The record is seen.json in the pack home (Get-MtPackHome), keyed by the repository's numeric ID and the
    commit, so a renamed repository keeps its record and a tag moved to another commit does not inherit one.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory)] [long] $RepositoryId,
        [Parameter(Mandatory)] [string] $Commit
    )

    $file = (Get-MtPackHome).Seen
    $seen = @{}
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        try { $seen = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop } catch { Write-Warning "Ignoring '$file': it is not valid JSON." }
        if ($null -eq $seen) { $seen = @{} }
    }
    $key = "$RepositoryId/$($Commit.ToLowerInvariant())"
    if ($seen.ContainsKey($key)) {
        # ConvertFrom-Json reads an ISO date as a DateTime already; [string] on it would drop the fraction of a second.
        $value = $seen[$key]
        if ($value -is [datetime]) { return $value.ToUniversalTime() }
        return ([datetime]::Parse([string]$value, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal))
    }
    $now = [datetime]::UtcNow
    $seen[$key] = $now.ToString('o', [cultureinfo]::InvariantCulture)
    $folder = Split-Path -Path $file -Parent
    if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -Path $folder -ItemType Directory -Force }
    [System.IO.File]::WriteAllText($file, ($seen | ConvertTo-Json -Depth 3), [System.Text.UTF8Encoding]::new($false))
    $now
}
