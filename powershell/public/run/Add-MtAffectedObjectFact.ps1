function Add-MtAffectedObjectFact {
    <#
    .SYNOPSIS
    Adds facts about an object, such as its last sign-in or its expired secrets, to the Affected objects page.

    .DESCRIPTION
    Call this from a test, an instance source or a pack that knows more about an object than the checks that name
    it: when the object was last used, which permissions it holds, whether its credentials have expired. The facts
    are shown with the object on the Affected objects page of the HTML report and kept in the AffectedObjects of the
    results, the JSON output and the objects files.

    Facts only describe an object that the run already lists. They are merged into the record with the same System,
    Type and Id when the results are built, so adding facts about an object that no check names adds nothing to the
    report. Facts are collected only while Invoke-Maester collects affected objects; otherwise the call does nothing.

    Each fact has a Name, a Value and a Tone: Risk for something to fix, Warning for something to review, Good for a
    sign that the object is in order, and Info (the default) for anything else. Adding a fact with the same Name from
    the same Source again replaces the earlier one.

    The value is shown as text. Name counts rather than other people where you can: the page shows facts to everyone
    who reads the report, and -RedactUserIdentity replaces only the names of users the run knows.

    .EXAMPLE
    Add-MtAffectedObjectFact -Type ServicePrincipal -Id $sp.id -Source 'Contoso inventory' -Fact @(
        @{ Name = 'Last sign-in'; Value = '2026-06-15 (143 days ago)'; Tone = 'Risk' }
        @{ Name = 'Publisher'; Value = 'Third party (Contoso Ltd)' }
    )

    Adds two facts to an enterprise application.

    .EXAMPLE
    $records | Add-MtAffectedObjectFact -Source 'Zero Trust Assessment' -AsOf $report.ExecutedAt

    Adds facts to many objects at once. Each record has Type, Id and Fact properties, and optionally System.

    .LINK
    https://maester.dev/docs/commands/Add-MtAffectedObjectFact
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        # The object type, as the Affected objects page records it: User, Group, ServicePrincipal, AppRegistration
        # (keyed by its appId), Device, ConditionalAccessPolicy, AgentIdentity, AgentIdentityBlueprint, ConfigurationPolicy...
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Type,

        # The object's id, the same id the record uses (for an app registration, its appId).
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        # The facts: hashtables or objects with Name, Value and an optional Tone (Risk, Warning, Good or Info).
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowEmptyCollection()]
        [object[]] $Fact,

        # Where the object lives: EntraID (the default), Intune, ExchangeOnline, GitHub...
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $System = 'EntraID',

        # What the facts come from, shown with them, for example 'Zero Trust Assessment'.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Source,

        # When the data behind the facts was read, when that is not now (a report written earlier).
        [Parameter()]
        [Nullable[datetime]] $AsOf
    )

    begin {
        $collecting = [bool]$__MtSession.IncludeAffectedObjects
        if (-not $collecting) {
            Write-Verbose 'Add-MtAffectedObjectFact: this run does not collect affected objects, so the facts are not kept.'
            return
        }
        if ($null -eq $__MtSession.AffectedObjectFacts) {
            $__MtSession.AffectedObjectFacts = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }
        $asOfText = if ($null -ne $AsOf) { $AsOf.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture) } else { $null }
        $tones = @('Risk', 'Warning', 'Good', 'Info')
    }

    process {
        if (-not $collecting) { return }

        $key = '{0}|{1}|{2}' -f $System, $Type, $Id
        $list = $null
        if (-not $__MtSession.AffectedObjectFacts.TryGetValue($key, [ref]$list)) {
            $list = [System.Collections.Generic.List[object]]::new()
            $__MtSession.AffectedObjectFacts[$key] = $list
        }

        foreach ($item in @($Fact)) {
            if ($null -eq $item) { continue }
            $name = [string](Get-ObjectProperty $item 'Name')
            $value = Get-ObjectProperty $item 'Value'
            if ([string]::IsNullOrWhiteSpace($name) -or $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { continue }
            $tone = [string](Get-ObjectProperty $item 'Tone')
            $tone = if ($tone) { $tones | Where-Object { $_ -eq $tone } | Select-Object -First 1 } else { 'Info' }
            if (-not $tone) {
                Write-Warning "Add-MtAffectedObjectFact: '$name' has the tone '$(Get-ObjectProperty $item 'Tone')', which is not Risk, Warning, Good or Info, so it is shown as Info."
                $tone = 'Info'
            }
            $text = ([string]$value).Trim()
            if ($text.Length -gt 300) { $text = $text.Substring(0, 297) + '...' }

            $index = $list.FindIndex({ param($existing) $existing.Name -eq $name -and $existing.Source -eq $Source })
            $record = [PSCustomObject]@{
                Name   = $name
                Value  = $text
                Tone   = $tone
                Source = $Source
                AsOf   = $asOfText
            }
            if ($index -ge 0) { $list[$index] = $record } else { $list.Add($record) }
        }
    }
}
