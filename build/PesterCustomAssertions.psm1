#Requires -Module Pester

## This module could probably use some clean up and performance optimization

function Format-Collection ($Value, [switch]$Pretty) {
    $Limit = 10
    $separator = ', '
    if ($Pretty) {
        $separator = ",`n"
    }
    $count = $Value.Count
    $trimmed = $count -gt $Limit

    $formattedCollection = @()
    for ($i = 0; $i -lt [System.Math]::Min($count, $Limit); $i++) {
        $formattedValue = Format-Nicely -Value $Value[$i] -Pretty:$Pretty
        $formattedCollection += $formattedValue
    }

    '@(' + ($formattedCollection -join $separator) + $(if ($trimmed) { ", ...$($count - $limit) more" }) + ')'
}

function Format-Object ($Value, $Property, [switch]$Pretty) {
    if ($null -eq $Property) {
        $Property = $Value.PSObject.Properties | & $SafeCommands['Select-Object'] -ExpandProperty Name
    }
    $valueType = Get-ShortType $Value
    $valueFormatted = ([string]([PSObject]$Value | & $SafeCommands['Select-Object'] -Property $Property))

    if ($Pretty) {
        $margin = "    "
        $valueFormatted = $valueFormatted `
            -replace '^@{', "@{`n$margin" `
            -replace '; ', ";`n$margin" `
            -replace '}$', "`n}" `

    }

    $valueFormatted -replace "^@", $valueType
}

function Format-Null {
    '$null'
}

function Format-String ($Value) {
    if ('' -eq $Value) {
        return '<empty>'
    }

    "'$Value'"
}

function Format-Date ($Value) {
    $Value.ToString('o')
}

function Format-Boolean ($Value) {
    '$' + $Value.ToString().ToLower()
}

function Format-ScriptBlock ($Value) {
    '{' + $Value + '}'
}

function Format-Number ($Value) {
    [string]$Value
}

function Format-Hashtable ($Value) {
    $head = '@{'
    $tail = '}'

    $entries = $Value.Keys | & $SafeCommands['Sort-Object'] | & $SafeCommands['ForEach-Object'] {
        $formattedValue = Format-Nicely $Value.$_
        "$_=$formattedValue" }

    $head + ( $entries -join '; ') + $tail
}

function Format-Dictionary ($Value) {
    $head = 'Dictionary{'
    $tail = '}'

    $entries = $Value.Keys | & $SafeCommands['Sort-Object'] | & $SafeCommands['ForEach-Object'] {
        $formattedValue = Format-Nicely $Value.$_
        "$_=$formattedValue" }

    $head + ( $entries -join '; ') + $tail
}

function Format-Nicely ($Value, [switch]$Pretty) {
    if ($null -eq $Value) {
        return Format-Null -Value $Value
    }

    if ($Value -is [bool]) {
        return Format-Boolean -Value $Value
    }

    if ($Value -is [string]) {
        return Format-String -Value $Value
    }

    if ($Value -is [DateTime]) {
        return Format-Date -Value $Value
    }

    if ($value -is [Type]) {
        return '[' + (Format-Type -Value $Value) + ']'
    }

    if (Is-DecimalNumber -Value $Value) {
        return Format-Number -Value $Value
    }

    if (Is-ScriptBlock -Value $Value) {
        return Format-ScriptBlock -Value $Value
    }

    if (Is-Value -Value $Value) {
        return $Value
    }

    if (Is-Hashtable -Value $Value) {
        # no advanced formatting of objects in the first version, till I balance it
        return [string]$Value
        #return Format-Hashtable -Value $Value
    }

    if (Is-Dictionary -Value $Value) {
        # no advanced formatting of objects in the first version, till I balance it
        return [string]$Value
        #return Format-Dictionary -Value $Value
    }

    if (Is-Collection -Value $Value) {
        return Format-Collection -Value $Value -Pretty:$Pretty
    }

    # no advanced formatting of objects in the first version, till I balance it
    return [string]$Value
    # Format-Object -Value $Value -Property (Get-DisplayProperty $Value) -Pretty:$Pretty
}

function Sort-Property ($InputObject, [string[]]$SignificantProperties, $Limit = 4) {

    $properties = @($InputObject.PSObject.Properties |
            & $SafeCommands['Where-Object'] { $_.Name -notlike "_*" } |
            & $SafeCommands['Select-Object'] -expand Name |
            & $SafeCommands['Sort-Object'])
    $significant = @()
    $rest = @()
    foreach ($p in $properties) {
        if ($significantProperties -contains $p) {
            $significant += $p
        }
        else {
            $rest += $p
        }
    }

    #todo: I am assuming id, name properties, so I am just sorting the selected ones by name.
    (@($significant | & $SafeCommands['Sort-Object']) + $rest) | & $SafeCommands['Select-Object'] -First $Limit

}

function Get-DisplayProperty ($Value) {
    Sort-Property -InputObject $Value -SignificantProperties 'id', 'name'
}

function Get-ShortType ($Value) {
    if ($null -ne $value) {
        $type = Format-Type $Value.GetType()
        # PSCustomObject serializes to the whole type name on normal PS but to
        # just PSCustomObject on PS Core

        $type `
            -replace "^System\." `
            -replace "^Management\.Automation\.PSCustomObject$", "PSObject" `
            -replace "^PSCustomObject$", "PSObject" `
            -replace "^Object\[\]$", "collection" `

    }
    else {
        Format-Type $null
    }
}

function Format-Type ([Type]$Value) {
    if ($null -eq $Value) {
        return '<none>'
    }

    [string]$Value
}

function Join-And ($Items, $Threshold = 2) {

    if ($null -eq $items -or $items.count -lt $Threshold) {
        $items -join ', '
    }
    else {
        $c = $items.count
        ($items[0..($c - 2)] -join ', ') + ' and ' + $items[-1]
    }
}

function Add-SpaceToNonEmptyString ([string]$Value) {
    if ($Value) {
        " $Value"
    }
}

function Get-DoValuesMatch($ActualValue, $ExpectedValue) {
    #user did not specify any message filter, so any message matches
    if ($null -eq $ExpectedValue) {
        return $true
    }

    return $ActualValue.ToString() -like $ExpectedValue
}

function Get-ExceptionLineInfo($info) {
    # $info.PositionMessage has a leading blank line that we need to account for in PowerShell 2.0
    $positionMessage = $info.PositionMessage -split '\r?\n' -match '\S' -join [System.Environment]::NewLine
    return ($positionMessage -replace "^At ", "from ")
}

function Format-Because ([string] $Because) {
    if ($null -eq $Because) {
        return
    }

    $bcs = $Because.Trim()
    if ([string]::IsNullOrEmpty($bcs)) {
        return
    }

    " because $($bcs -replace 'because\s'),"
}


function Should-WriteError ([scriptblock] $ActualValue, [string] $ExpectedMessage, [string] $ErrorId, [type] $ExceptionType, [switch] $Negate, [string] $Because, [switch] $PassThruError, [switch] $PassThruOutput) {

    if ($null -eq $ActualValue) {
        throw [ArgumentNullException] "Input is not a ScriptBlock. Input to '-Throw' and '-Not -Throw' must be enclosed in curly braces."
    }

    try {
        $output = Invoke-Command $ActualValue -ErrorVariable actualErrors
    }
    catch {}

    if (!$Negate -and @($actualErrors).Count -eq 0) {
        # this is for Should -Not -Throw. Once *any* exception was thrown we should fail the assertion
        # there is no point in filtering the exception, because there should be none
        $failureMessage = "Expected error,$(Format-Because $Because) but no error was returned."
        return [PSCustomObject] @{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }

    # the rest is for Should -Throw, we must fail the assertion when no exception is thrown
    # or when the exception does not match our filter

    function Join-And ($Items, $Threshold = 2) {

        if ($null -eq $items -or $items.count -lt $Threshold) {
            $items -join ', '
        }
        else {
            $c = $items.count
            ($items[0..($c - 2)] -join ', ') + ' and ' + $items[-1]
        }
    }

    function Add-SpaceToNonEmptyString ([string]$Value) {
        if ($Value) {
            " $Value"
        }
    }

    $filters = @()

    $filterOnExceptionType = $null -ne $ExceptionType
    if ($filterOnExceptionType) {
        $filters += "of type $(Format-Nicely $ExceptionType)"
    }

    $filterOnMessage = -not [string]::IsNullOrWhitespace($ExpectedMessage)
    if ($filterOnMessage) {
        $filters += "with message $(Format-Nicely $ExpectedMessage)"
    }

    $filterOnId = -not [string]::IsNullOrWhitespace($ErrorId)
    if ($filterOnId) {
        $filters += "with FullyQualifiedErrorId $(Format-Nicely $ErrorId)"
    }

    $buts = @()
    $match = @()
    foreach ($actualError in $actualErrors) {
        if ($actualError -is [System.Management.Automation.ErrorRecord]) {
            
            $matchOnExceptionType = !$filterOnExceptionType -or $actualError.Exception -is $ExceptionType
            $matchOnMessage = !$filterOnMessage -or (Get-DoValuesMatch $actualError.Exception.Message $ExpectedMessage)
            $matchOnId = !$filterOnId -or (Get-DoValuesMatch $actualError.FullyQualifiedErrorId $ErrorId)
            if ($matchOnExceptionType -and $matchOnMessage -and $matchOnId) {
                $match += $actualError
                #break
            }
        }
    }
    
    if ($match) {
        $actualExceptionLine = (Get-ExceptionLineInfo $_.InvocationInfo) -replace [System.Environment]::NewLine, "$([System.Environment]::NewLine)    "
        if ($Negate) { $buts += "matching error was returned. $actualExceptionLine" }
    }
    elseif (!$Negate) {
        $buts += "no matching error was returned"
    }

    $expected = ''
    if ($Negate) { $expected = ' no' }
    

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $failureMessage = "Expected$expected error$filter to be returned,$(Format-Because $Because) but $but.".Trim()

        return [PSCustomObject] @{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }

    $result = [PSCustomObject] @{
        Succeeded = $true
    }

    if ($PassThruError -or $PassThruOutput) {
        [array] $data = @()

        if ($PassThruError) {
            $data += $match
        }

        if ($PassThruOutput) {
            $data += $output
        }

        $result | Add-Member -MemberType NoteProperty -Name 'Data' -Value $data
    }

    return $result
}


Add-ShouldOperator -Name WriteError -InternalName 'Should-WriteError' -Test ${function:Should-WriteError} -Alias 'Error'
