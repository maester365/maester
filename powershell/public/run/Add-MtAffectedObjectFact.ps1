function Add-MtAffectedObjectFact {
    <#
    .SYNOPSIS
    Adds facts about an object, such as its last sign-in or its expired secrets, to the Affected objects page.

    .DESCRIPTION
    Call this from a test, an instance source or a pack that knows more about an object than the checks that name
    it: when the object was last used, which permissions it holds, whether its credentials have expired. The facts
    are shown with the object on the Affected objects page of the HTML report and kept in the AffectedObjects of the
    results, the JSON output and the objects files.

    Add-MtTestResultDetail -GraphObjects says which objects a result is about, and adds them to the page with the check
    that named them. Add-MtAffectedObjectFact says what is known about an object, whichever check named it.

    Facts only describe an object that the run already lists. They are merged into the record with the same System,
    Type and Id when the results are built, so adding facts about an object that no check names adds nothing to the
    report. Facts are collected only while Invoke-Maester collects affected objects; otherwise the call does nothing.

    Each fact has a Name, a Value and a Tone: Risk for something to fix, Warning for something to review, Good for a
    sign that the object is in order, and Info (the default) for anything else.

    A fact can also carry a Key and a Raw value, for code that reads the results: a summary, an insight or another
    report. The Key names what the fact is about, from the shared list of fact keys (user.mfaRegistered,
    signIn.daysSince, device.managed...), so the same fact from two sources means the same thing. Raw is its value as
    data: a boolean, a number, a string, a list of strings or a date, which is kept as an ISO 8601 UTC string. Value
    stays the text people read. Raw is kept only with a Key. A fact without a Key is shown the same way.

    Adding a fact with the same Key, or without a Key the same Name, from the same Source again replaces the earlier one.

    The value is shown as text. Name counts rather than other people where you can: the page shows facts to everyone
    who reads the report, and -RedactUserIdentity replaces only the names of users the run knows.

    .EXAMPLE
    Add-MtAffectedObjectFact -Type ServicePrincipal -Id $sp.id -Source 'Contoso inventory' -Fact @(
        @{ Name = 'Last sign-in'; Value = '2026-06-15 (143 days ago)'; Tone = 'Risk' }
        @{ Name = 'Publisher'; Value = 'Third party (Contoso Ltd)' }
    )

    Adds two facts to an enterprise application.

    .EXAMPLE
    Add-MtAffectedObjectFact -Type User -Id $user.id -Source 'Contoso HR' -Fact @(
        @{ Name = 'MFA'; Value = 'Not registered'; Tone = 'Risk'; Key = 'user.mfaRegistered'; Raw = $false }
        @{ Name = 'Last sign-in'; Value = '2026-06-15 (143 days ago)'; Tone = 'Warning'; Key = 'signIn.daysSince'; Raw = 143 }
    )

    Adds facts with keys, so code can read whether the user has MFA and how long since they signed in without
    parsing the text.

    .EXAMPLE
    $records | Add-MtAffectedObjectFact -Source 'Zero Trust Assessment' -AsOf $report.ExecutedAt

    Adds facts to many objects at once. Each record has Type, Id and Fact properties, and optionally System.

    .LINK
    https://maester.dev/docs/commands/Add-MtAffectedObjectFact

    .LINK
    https://maester.dev/docs/writing-tests/formatting-test-results#adding-facts-about-an-object

    .LINK
    https://maester.dev/docs/writing-tests/formatting-test-results#fact-keys
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

        # The facts: hashtables or objects with Name, Value, and optionally Tone (Risk, Warning, Good or Info), Key (a
        # shared fact key such as user.mfaRegistered) and Raw (its value as data).
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
        # Dotted camelCase segments: user.mfaRegistered, signIn.daysSince, app.highPrivilegePermissions.
        $keyPattern = '^[a-z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)+$'
        # Raw is kept as JSON-friendly data: a boolean, a number, a string, a list of strings, or a date as ISO text.
        $toRaw = {
            param($Raw, [string] $FactName)
            if ($null -eq $Raw) { return , $null }
            if ($Raw -is [bool] -or $Raw -is [string]) { return , $Raw }
            if ($Raw -is [int] -or $Raw -is [long] -or $Raw -is [double] -or $Raw -is [decimal] -or $Raw -is [single]) { return , $Raw }
            if ($Raw -is [datetime]) { return , $Raw.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture) }
            if ($Raw -is [datetimeoffset]) { return , $Raw.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture) }
            if ($Raw -is [System.Collections.IEnumerable] -and $Raw -isnot [System.Collections.IDictionary]) {
                return , [string[]]@($Raw | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
            }
            Write-Warning "Add-MtAffectedObjectFact: the Raw value of '$FactName' is a $($Raw.GetType().Name), not a boolean, number, string, list or date, so it is left out."
            return , $null
        }
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

            $factKey = [string](Get-ObjectProperty $item 'Key')
            if ($factKey -and $factKey -cnotmatch $keyPattern) {
                Write-Warning "Add-MtAffectedObjectFact: '$factKey' is not a fact key (dotted camelCase, such as user.mfaRegistered), so '$name' is kept without one."
                $factKey = ''
            }
            # Raw only means something next to a Key, which says how to read it.
            # Read directly: Get-ObjectProperty writes to the pipeline, which turns a one-item list into a string.
            $rawInput = $null
            if ($item -is [System.Collections.IDictionary]) { $rawInput = $item['Raw'] }
            elseif ($item.PSObject.Properties['Raw']) { $rawInput = $item.PSObject.Properties['Raw'].Value }
            $raw = $null
            # Assigned inside the if: an if expression would unroll a list Raw again.
            if ($factKey) { $raw = & $toRaw $rawInput $name }

            $index = if ($factKey) {
                $list.FindIndex({ param($existing) $existing.Key -ceq $factKey -and $existing.Source -eq $Source })
            } else {
                $list.FindIndex({ param($existing) -not $existing.Key -and $existing.Name -eq $name -and $existing.Source -eq $Source })
            }
            $record = [PSCustomObject]@{
                Name   = $name
                Value  = $text
                Tone   = $tone
                Key    = if ($factKey) { $factKey } else { $null }
                Raw    = $raw
                Source = $Source
                AsOf   = $asOfText
            }
            if ($index -ge 0) { $list[$index] = $record } else { $list.Add($record) }
        }
    }
}
