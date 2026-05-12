function Test-MtZtaFreshness {
    <#
    .SYNOPSIS
        Internal: returns how stale a ZTA artifact is and whether it exceeds the configured
        freshness threshold.

    .DESCRIPTION
        Timestamp source priority:
          1. ManifestRunStartTime    — manifest.json.runStartTime (most authoritative)
          2. JsonExecutedAt          — ZeroTrustAssessmentReport.json's ExecutedAt field
          3. DbMtime                 — zt.db file mtime (least authoritative; warns)

        Returns:
            [pscustomobject] {
                IsStale         = [bool]
                AgeDays         = [int]
                Threshold       = [int]
                TimestampSource = [string]   # one of the three above, or 'None'
                Timestamp       = [datetime] # the resolved timestamp (UTC)
            }

        Caller (Import-MtZtaResult) is responsible for the side effects when stale.
        Run still proceeds — warn-but-proceed semantics.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The bundle root (folder, .tar.gz / .zip already extracted) containing
        # manifest.json + ZeroTrustAssessmentReport.json + db/zt.db.
        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $false)]
        [int] $FreshnessDays = 14
    )

    if (-not (Test-Path $BundlePath)) {
        throw "Test-MtZtaFreshness: bundle path not found: $BundlePath"
    }

    $manifestFile = Join-Path $BundlePath 'manifest.json'
    $jsonFile     = Join-Path $BundlePath 'ZeroTrustAssessmentReport.json'
    $dbFile       = Join-Path $BundlePath 'db/zt.db'

    $timestamp = $null
    $source    = 'None'

    # Priority 1: manifest.json.runStartTime
    if (Test-Path $manifestFile) {
        try {
            $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($manifest.PSObject.Properties['runStartTime'] -and $manifest.runStartTime) {
                $timestamp = [datetime]::Parse($manifest.runStartTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                $source = 'ManifestRunStartTime'
            }
        }
        catch {
            Write-Verbose "Test-MtZtaFreshness: manifest.json.runStartTime unreadable ($($_.Exception.Message)); falling through."
        }
    }

    # Priority 2: ZeroTrustAssessmentReport.json's ExecutedAt
    if (-not $timestamp -and (Test-Path $jsonFile)) {
        try {
            $report = Get-Content $jsonFile -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($report.PSObject.Properties['ExecutedAt'] -and $report.ExecutedAt) {
                $timestamp = [datetime]::Parse($report.ExecutedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                $source = 'JsonExecutedAt'
            }
        }
        catch {
            Write-Verbose "Test-MtZtaFreshness: ZeroTrustAssessmentReport.json ExecutedAt unreadable ($($_.Exception.Message)); falling through."
        }
    }

    # Priority 3: zt.db file mtime — least authoritative, warns
    if (-not $timestamp -and (Test-Path $dbFile)) {
        $timestamp = (Get-Item $dbFile).LastWriteTimeUtc
        $source    = 'DbMtime'
        Write-Warning "Test-MtZtaFreshness: derived from zt.db file mtime ($timestamp); manifest + JSON timestamps unavailable. Result may be unreliable on copied or re-downloaded artifacts."
    }

    if (-not $timestamp) {
        Write-Warning "Test-MtZtaFreshness: no timestamp source found in $BundlePath. Manifest, JSON, and DB are all unreadable or absent."
        return [pscustomobject]@{
            IsStale         = $false
            AgeDays         = -1
            Threshold       = $FreshnessDays
            TimestampSource = 'None'
            Timestamp       = $null
        }
    }

    $now     = [datetime]::UtcNow
    # Clamp future-dated timestamps to 0 — bundles produced on a host whose clock
    # is ahead of the runner produce a negative raw age, which downstream renderers
    # turn into a "-N%" chip. Zero is the correct "fresh" sentinel.
    $rawAge  = ($now - $timestamp).TotalDays
    $ageDays = if ($rawAge -lt 0) { 0 } else { [int][math]::Floor($rawAge) }
    $isStale = $ageDays -gt $FreshnessDays

    [pscustomobject]@{
        IsStale         = $isStale
        AgeDays         = $ageDays
        Threshold       = $FreshnessDays
        TimestampSource = $source
        Timestamp       = $timestamp
    }
}
