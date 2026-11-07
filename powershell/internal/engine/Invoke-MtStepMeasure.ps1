function Invoke-MtStepMeasure {
    <#
    .SYNOPSIS
    Reads the measures of the defender's path steps that a run covers, after its tests.

    .DESCRIPTION
    A measure is a figure the engine reads from Graph for a step that is a state of the tenant
    (docs/proposals/defenders-path.md, section 11). Measures are not selected: after the tests, the engine reads the
    measure of every step in scope (Get-MtStepScope), so a run of one test still shows the figures of its
    prerequisites. Each measure is read once, even when several steps name it.

    A measure is gated like a test: every Service must be connected, the tenant must have one of the License plans
    when its licences are known, and when the Graph connection lists its permissions, each Permission element must
    have an alternative it holds (a Graph:Scope permission the connection has, or its ReadWrite form; other kinds
    can't be checked and count as held). A measure whose gate fails isn't read and carries the reason code a test
    would: ServiceNotConnected, LicenseNotFound, or PermissionNotGranted. A reader that throws gives MeasureError,
    or PermissionNotGranted when Graph answered 403. Readers go through the session cache like the checks.

    The readers may add object facts with Add-MtAffectedObjectFact, so call this while the run collects affected
    objects.

    Returns a hashtable of measure key to the raw reading: Key, Count, Total, Objects (all the objects that fall
    short, as the reader returned them), ReadAt (ISO 8601 UTC), ReasonCode and ReasonDetail. Count, Total and Objects
    are $null and ReasonCode set when the measure could not be read. Returns an empty hashtable when no step in scope
    has a measure, or when -Disabled.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # The result rows of the run, with Result and Step.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $InputObject = @(),

        # The tenant context of the run: connected services, licences and the permissions of the Graph connection.
        [Parameter()] [AllowNull()] [object] $TenantContext,

        # The run config turned measures off (Measures.Enabled = false).
        [Parameter()] [switch] $Disabled,

        # The step catalogue. Defaults to the module's.
        [Parameter()] [object] $Catalog = (Get-MtStepCatalog),

        # The measure registry. Defaults to the module's.
        [Parameter()] [object] $Registry = (Get-MtMeasureRegistry)
    )

    $readings = @{}
    if ($Disabled) { return $readings }
    $scope = Get-MtStepScope -InputObject $InputObject -Catalog $Catalog
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($id in $scope.Steps) {
        $measure = $Catalog.Steps[$id].Measure
        if ($measure -and -not $keys.Contains($measure.Key)) { $keys.Add($measure.Key) }
    }

    $enforce = @{ Service = $true; License = $true; TenantType = $false; Cloud = $false }
    $scopes = @(if ($TenantContext -and $TenantContext.PSObject.Properties['Scopes']) { $TenantContext.Scopes | Where-Object { $_ } })
    foreach ($key in $keys) {
        $reading = [pscustomobject][ordered]@{ Key = $key; Count = $null; Total = $null; Objects = $null; ReadAt = $null; ReasonCode = $null; ReasonDetail = $null }
        $readings[$key] = $reading
        $entry = $null
        if (-not $Registry.Measures.TryGetValue($key, [ref] $entry)) {
            $reading.ReasonCode = 'MeasureError'; $reading.ReasonDetail = "The measure registry has no measure '$key'."
            continue
        }

        # The gates of a test: services, then licences.
        $gate = Test-MtApplicability -Test ([pscustomobject]@{ Platform = @(); TenantType = @(); Cloud = @(); UnregisteredServices = @(); Service = $entry.Service; License = $entry.License }) -TenantContext $TenantContext -Enforce $enforce
        if ($gate) { $reading.ReasonCode = $gate.ReasonCode; $reading.ReasonDetail = $gate.ReasonDetail; continue }

        # Permissions, when the Graph connection lists the ones it holds.
        if ($scopes.Count -gt 0) {
            $missing = foreach ($element in $entry.Permission) {
                $held = $false
                foreach ($alternative in @(ConvertFrom-MtPermission -Value $element)) {
                    if ($alternative.Service -ne 'Graph' -or $alternative.Kind -ne 'Scope') { $held = $true; break }
                    $readWrite = $alternative.Name -replace '\.Read\.', '.ReadWrite.'
                    if ($scopes | Where-Object { $_ -eq $alternative.Name -or $_ -eq $readWrite }) { $held = $true; break }
                }
                if (-not $held) { $element }
            }
            if (@($missing).Count -gt 0) {
                $reading.ReasonCode = 'PermissionNotGranted'
                $reading.ReasonDetail = "The Graph connection lacks a permission this figure needs: $(@($missing) -join '; ')."
                continue
            }
        }

        try {
            Write-Verbose "Reading the measure $key with $($entry.Function)."
            $value = & $entry.Function -ErrorAction Stop
            $reading.Count = [int]$value.Count
            $reading.Total = [int]$value.Total
            $reading.Objects = @($value.Objects | Where-Object { $null -ne $_ })
        } catch {
            $message = Get-MtFirstLine $_.Exception.Message
            $forbidden = $_.Exception.Message -match '\b403\b|Forbidden|Authorization_RequestDenied'
            $reading.ReasonCode = if ($forbidden) { 'PermissionNotGranted' } else { 'MeasureError' }
            $reading.ReasonDetail = $message
            Write-Verbose "The measure $key could not be read: $message"
        }
        $reading.ReadAt = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
    }
    $readings
}
