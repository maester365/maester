function Read-MtNativeTest {
    <#
    .SYNOPSIS
    Reads a native test file (Test.<ID>.ps1) from its AST and validates its [MaesterTest] metadata.

    .DESCRIPTION
    The file is parsed, never executed (design section 3.2). Returns one object with the attribute
    properties, the test function's name, its parameters (name, type, default, allowed values, range,
    kind and description), the paired .md file and a list of Errors. An error has a Code from the
    closed list (InvalidMetadata, LoadFailed, RequiresNewerMaester), a Message and a Line.

    Rules: exactly one [MaesterTest] function per file; named arguments only; constant values only;
    at the top level only function definitions; the file name is Test.<Id>.ps1; parameters are int,
    bool, switch, string or string[] with constant defaults and none mandatory; [CmdletBinding()] is
    required.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Path to a Test.<ID>.ps1 file.
        [Parameter(Mandatory)]
        [string] $Path,

        # The test ships with Maester: the BuiltIn-required properties must be present and services must be registered.
        [Parameter()]
        [switch] $BuiltIn
    )

    $schema = Get-MtTestSchema
    $registry = Get-MtServiceRegistry
    $errors = [System.Collections.Generic.List[pscustomobject]]::new()
    $file = (Resolve-Path -LiteralPath $Path).Path
    $test = [ordered]@{
        File              = $file
        FunctionName      = $null
        Line              = 1
        Id                = $null
        Title             = $null
        Severity          = $null
        Category          = $null
        Tag               = @()
        Preview           = $false
        LongRunning       = $false
        Service           = @()
        License = @()
        TenantType        = @()
        Cloud             = @()
        Platform          = @()
        InstanceSource    = $null
        Exclusive         = $false
        Author            = @()
        Contributor       = @()
        HelpUrl           = $null
        Parameters        = @()
        UnregisteredServices = @()
        MarkdownPath      = $null
        RequiresMaester   = $null
        BuiltIn           = $BuiltIn.IsPresent
        Errors            = $errors
    }
    $addError = { param($code, $message, $line) $errors.Add([pscustomobject]@{ Code = $code; Message = $message; Line = $line }) }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)

    # The ID is still worth knowing when the file does not parse, so its row can name it.
    $fileId = ([System.IO.Path]::GetFileName($file) -replace '^Test\.', '' -replace '\.ps1$', '')
    if ($parseErrors) {
        $test.Id = $fileId
        foreach ($e in ($parseErrors | Select-Object -First 3)) { & $addError 'LoadFailed' "The file does not parse: $($e.Message)" $e.Extent.StartLineNumber }
        return [pscustomobject]$test
    }

    # #Requires -Modules Maester -Version x.y
    if ($ast.ScriptRequirements) {
        $requiresMaester = $ast.ScriptRequirements.RequiredModules | Where-Object { $_.Name -eq 'Maester' } | Select-Object -First 1
        if ($requiresMaester) {
            $test.RequiresMaester = if ($requiresMaester.RequiredVersion) { $requiresMaester.RequiredVersion } elseif ($requiresMaester.Version) { $requiresMaester.Version } else { $null }
        }
    }

    # Top level: function definitions only.
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
            & $addError 'InvalidMetadata' "A test file may contain only function definitions at the top level; found '$($statement.Extent.Text.Split("`n")[0].Trim())'." $statement.Extent.StartLineNumber
        }
    }
    foreach ($block in @($ast.BeginBlock, $ast.ProcessBlock, $ast.DynamicParamBlock)) {
        if ($block -and $block.Statements.Count -gt 0) { & $addError 'InvalidMetadata' 'A test file may contain only function definitions at the top level.' $block.Extent.StartLineNumber }
    }
    if ($ast.ParamBlock) { & $addError 'InvalidMetadata' 'A test file must not have a script-level param() block.' $ast.ParamBlock.Extent.StartLineNumber }

    $functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
    $testFunctions = @($functions | Where-Object {
            $_.Body.ParamBlock -and ($_.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -in 'MaesterTest', 'MaesterTestAttribute' })
        })
    if ($testFunctions.Count -ne 1) {
        $test.Id = $fileId
        $message = if ($testFunctions.Count -eq 0) { 'The file has no function with a [MaesterTest(...)] attribute.' } else { 'The file has more than one function with a [MaesterTest(...)] attribute.' }
        & $addError 'InvalidMetadata' $message 1
        return [pscustomobject]$test
    }

    $function = $testFunctions[0]
    $test.FunctionName = $function.Name
    $test.Line = $function.Extent.StartLineNumber
    $attribute = $function.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -in 'MaesterTest', 'MaesterTestAttribute' } | Select-Object -First 1

    if ($attribute.PositionalArguments.Count -gt 0) {
        & $addError 'InvalidMetadata' '[MaesterTest] takes named arguments only, for example [MaesterTest(Id = ''CONTOSO.1001'', Title = ''...'')].' $attribute.Extent.StartLineNumber
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($named in $attribute.NamedArguments) {
        $name = $named.ArgumentName
        $line = $named.Extent.StartLineNumber
        if (-not $seen.Add($name)) { & $addError 'InvalidMetadata' "Property '$name' is set more than once." $line; continue }

        $definition = $null
        foreach ($key in $schema.Properties.Keys) { if ($key -eq $name) { $definition = $schema.Properties[$key]; $name = $key } }
        if (-not $definition) {
            $hint = if ($name -in $schema.ReservedNames) { ' It is reserved for a later Maester version.' } else { ' It may come from a newer version of Maester.' }
            & $addError 'InvalidMetadata' "Unknown [MaesterTest] property '$($named.ArgumentName)'.$hint" $line
            continue
        }

        $value = ConvertFrom-MtAttributeArgument -NamedArgument $named
        if ($value.Error) { & $addError 'InvalidMetadata' "Property '$name': $($value.Error)" $line; continue }
        $values = @($value.Values)

        # (No 'continue' inside the switch: there it would only leave the switch.)
        $typeError = $null
        if ($definition.Type -eq 'bool') {
            if ($values.Count -ne 1 -or $values[0] -isnot [bool]) { $typeError = "Property '$name' must be `$true, `$false or a bare flag." }
            else { $test[$name] = $values[0] }
        } elseif ($definition.Type -eq 'string') {
            if ($values.Count -ne 1 -or $values[0] -isnot [string]) { $typeError = "Property '$name' must be a single string." }
            else { $test[$name] = $values[0] }
        } else {
            if ($values.Count -eq 0 -or ($values | Where-Object { $_ -isnot [string] })) { $typeError = "Property '$name' must be a string or a list of strings." }
            else { $test[$name] = @($values) }
        }
        if ($typeError) { & $addError 'InvalidMetadata' $typeError $line; continue }
        if ($definition.Type -eq 'bool') { continue }

        foreach ($v in @($test[$name])) {
            if ($definition.Pattern -and $v -notmatch $definition.Pattern) {
                & $addError 'InvalidMetadata' "Property '$name' value '$v' is not valid." $line
            }
            if ($definition.MaxLength -and $v.Length -gt $definition.MaxLength) {
                & $addError 'InvalidMetadata' "Property '$name' value is longer than $($definition.MaxLength) characters." $line
            }
            if ($definition.AllowedValues) {
                $match = $definition.AllowedValues | Where-Object { $_ -eq $v } | Select-Object -First 1
                if (-not $match) { & $addError 'InvalidMetadata' "Property '$name' value '$v' is not one of $($definition.AllowedValues -join ', '). It may come from a newer version of Maester." $line }
            }
        }
    }

    # Normalise allowed values to their canonical spelling, and services to registry names.
    foreach ($name in 'Severity', 'TenantType', 'Cloud', 'Platform') {
        $allowed = $schema.Properties[$name].AllowedValues
        $test[$name] = if ($schema.Properties[$name].Type -eq 'string') {
            if ($test[$name]) { $allowed | Where-Object { $_ -eq $test[$name] } | Select-Object -First 1 } else { $null }
        } else {
            @($test[$name] | ForEach-Object { $v = $_; $allowed | Where-Object { $_ -eq $v } | Select-Object -First 1 } | Where-Object { $_ })
        }
    }
    $services = [System.Collections.Generic.List[string]]::new()
    $unregistered = [System.Collections.Generic.List[string]]::new()
    foreach ($s in @($test.Service)) {
        if ($s -eq 'None') { continue }
        $canonical = Resolve-MtServiceName -Name $s -Registry $registry
        if ($canonical) { $services.Add($canonical) }
        elseif ($BuiltIn) { & $addError 'InvalidMetadata' "Service '$s' is not in the service registry ($(@($registry.Services.Keys | Sort-Object) -join ', '))." $attribute.Extent.StartLineNumber }
        else { $unregistered.Add($s) }
    }
    $test.Service = @($services | Select-Object -Unique)
    $test.UnregisteredServices = $unregistered.ToArray()

    foreach ($name in $schema.Properties.Keys) {
        $required = $schema.Properties[$name].Required
        if ($required -eq 'Always' -or ($required -eq 'BuiltIn' -and $BuiltIn)) {
            $present = $seen.Contains($name)
            if (-not $present) { & $addError 'InvalidMetadata' "[MaesterTest] property '$name' is required." $attribute.Extent.StartLineNumber }
        }
    }

    if ($test.Id -and -not ([System.IO.Path]::GetFileName($file) -ieq "Test.$($test.Id).ps1")) {
        & $addError 'InvalidMetadata' "The file name must be Test.$($test.Id).ps1." 1
    }
    if ($test.InstanceSource -and -not ($functions | Where-Object { $_.Name -eq $test.InstanceSource })) {
        & $addError 'InvalidMetadata' "InstanceSource '$($test.InstanceSource)' is not a function defined in this file." $attribute.Extent.StartLineNumber
    }

    # Parameters.
    if (-not ($function.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' })) {
        & $addError 'InvalidMetadata' 'The test function must have [CmdletBinding()].' $function.Body.ParamBlock.Extent.StartLineNumber
    }
    $test.Parameters = @(foreach ($parameter in $function.Body.ParamBlock.Parameters) {
            Read-MtTestParameter -ParameterAst $parameter -Tokens $tokens -HelpContent $function.GetHelpContent() -OnError $addError
        })

    $markdown = [System.IO.Path]::ChangeExtension($file, '.md')
    if (Test-Path -LiteralPath $markdown) { $test.MarkdownPath = $markdown }
    elseif (-not $BuiltIn) { & $addError 'InvalidMetadata' "The test has no Markdown file. Create $([System.IO.Path]::GetFileName($markdown)) next to it." 1 }

    if ($test.RequiresMaester) {
        $current = $ExecutionContext.SessionState.Module.Version
        if ([version]$test.RequiresMaester -gt $current) {
            & $addError 'RequiresNewerMaester' "The test requires Maester $($test.RequiresMaester) or later; this is $current." 1
        }
    }

    [pscustomobject]$test
}

function ConvertFrom-MtAttributeArgument {
    <#
    .SYNOPSIS
    Returns the constant value(s) of a named attribute argument, or an error for anything not constant.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.NamedAttributeArgumentAst] $NamedArgument
    )

    if ($NamedArgument.ExpressionOmitted) { return [pscustomobject]@{ Values = @($true); Error = $null } }
    $expression = $NamedArgument.Argument
    # ('a', 'b') is a parenthesised pipeline around an array literal.
    while ($expression -is [System.Management.Automation.Language.ParenExpressionAst]) {
        $pipeline = $expression.Pipeline
        if ($pipeline -is [System.Management.Automation.Language.PipelineAst] -and $pipeline.PipelineElements.Count -eq 1 -and
            $pipeline.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) {
            $expression = $pipeline.PipelineElements[0].Expression
        } else {
            return [pscustomobject]@{ Values = @(); Error = 'only constant values are allowed.' }
        }
    }

    $elements = if ($expression -is [System.Management.Automation.Language.ArrayLiteralAst]) { $expression.Elements } else { @($expression) }
    $values = foreach ($e in $elements) {
        if ($e -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $e.StringConstantType -ne 'BareWord') { $e.Value }
        elseif ($e -is [System.Management.Automation.Language.VariableExpressionAst] -and $e.VariablePath.UserPath -in 'true', 'false') { $e.VariablePath.UserPath -eq 'true' }
        else { return [pscustomobject]@{ Values = @(); Error = "'$($e.Extent.Text)' is not a constant. Use quoted strings, `$true, `$false or a list such as ('a', 'b')." } }
    }
    [pscustomobject]@{ Values = @($values); Error = $null }
}

function Read-MtTestParameter {
    <#
    .SYNOPSIS
    Reads one parameter of a test function: type, default, allowed values, range, kind and description.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [System.Management.Automation.Language.ParameterAst] $ParameterAst,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Tokens,
        [Parameter()] [AllowNull()] [object] $HelpContent,
        [Parameter(Mandatory)] [scriptblock] $OnError
    )

    $name = $ParameterAst.Name.VariablePath.UserPath
    $line = $ParameterAst.Extent.StartLineNumber
    $typeName = 'object'
    $allowed = $null
    $range = $null
    $kind = $null
    $mandatory = $false
    foreach ($a in $ParameterAst.Attributes) {
        if ($a -is [System.Management.Automation.Language.TypeConstraintAst]) {
            $typeName = $a.TypeName.FullName.ToLowerInvariant()
            continue
        }
        switch ($a.TypeName.Name) {
            'ValidateSet' { $allowed = @($a.PositionalArguments | ForEach-Object { $_.SafeGetValue() }) }
            'ValidateRange' { if ($a.PositionalArguments.Count -eq 2) { $range = @($a.PositionalArguments[0].SafeGetValue(), $a.PositionalArguments[1].SafeGetValue()) } }
            { $_ -in 'MaesterParameter', 'MaesterParameterAttribute' } {
                $k = $a.NamedArguments | Where-Object ArgumentName -EQ 'Kind' | Select-Object -First 1
                if ($k -and $k.Argument -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $kind = $k.Argument.Value }
                else { & $OnError 'InvalidMetadata' "Parameter '$name': [MaesterParameter] needs Kind = '<kind>'." $line }
            }
            'Parameter' {
                $m = $a.NamedArguments | Where-Object ArgumentName -EQ 'Mandatory' | Select-Object -First 1
                if ($m -and ($m.ExpressionOmitted -or $m.Argument.Extent.Text -eq '$true')) { $mandatory = $true }
            }
        }
    }
    $typeName = switch ($typeName) {
        { $_ -in 'int', 'int32', 'system.int32' } { 'int' }
        { $_ -in 'bool', 'boolean', 'system.boolean' } { 'bool' }
        { $_ -in 'switch', 'system.management.automation.switchparameter' } { 'switch' }
        { $_ -in 'string', 'system.string' } { 'string' }
        { $_ -in 'string[]', 'system.string[]' } { 'string[]' }
        default { $_ }
    }

    $default = $null
    $hasDefault = $null -ne $ParameterAst.DefaultValue
    if ($hasDefault) {
        try { $default = $ParameterAst.DefaultValue.SafeGetValue() }
        catch { & $OnError 'InvalidMetadata' "Parameter '$name': the default value must be a constant." $line }
    }

    $engineOwned = $name -eq 'Instance' -or $name -like 'Mt*'
    if (-not $engineOwned) {
        if ($typeName -notin 'int', 'bool', 'switch', 'string', 'string[]') { & $OnError 'InvalidMetadata' "Parameter '$name': type '$typeName' is not supported. Use int, bool, switch, string or string[]." $line }
        if ($mandatory) { & $OnError 'InvalidMetadata' "Parameter '$name' must not be mandatory: a test must run with an empty configuration." $line }
    }

    # Description: a comment directly above the parameter, else .PARAMETER help.
    $description = $null
    $start = $ParameterAst.Extent.StartOffset
    # Consecutive # lines directly above the parameter form one description.
    $before = @($Tokens | Where-Object { $_.Extent.EndOffset -le $start -and $_.Kind -ne 'NewLine' })
    $lines = [System.Collections.Generic.List[string]]::new()
    $expectedLine = $ParameterAst.Extent.StartLineNumber - 1
    for ($i = $before.Count - 1; $i -ge 0; $i--) {
        $token = $before[$i]
        if ($token.Kind -ne 'Comment' -or $token.Extent.EndLineNumber -lt $expectedLine) { break }
        $lines.Insert(0, ($token.Text -replace '^<#|#>$', '' -replace '^#\s?', '').Trim())
        $expectedLine = $token.Extent.StartLineNumber - 1
    }
    if ($lines.Count -gt 0) { $description = (($lines | Where-Object { $_ }) -join ' ').Trim() }
    if (-not $description) {
        # A comment between the attributes and the variable: [Parameter()] # Description. [switch] $Name
        $inside = $Tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.StartOffset -ge $start -and $_.Extent.EndOffset -le $ParameterAst.Name.Extent.StartOffset } | Select-Object -Last 1
        if ($inside) { $description = ($inside.Text -replace '^<#|#>$', '' -replace '^#\s?', '').Trim() }
    }
    if (-not $description -and $HelpContent -and $HelpContent.Parameters -and $HelpContent.Parameters.ContainsKey($name.ToUpperInvariant())) {
        $description = $HelpContent.Parameters[$name.ToUpperInvariant()].Trim()
    }

    [pscustomobject]@{
        Name          = $name
        Type          = $typeName
        Default       = $default
        HasDefault    = $hasDefault
        AllowedValues = $allowed
        Range         = $range
        Kind          = $kind
        Description   = $description
        EngineOwned   = $engineOwned
    }
}

function Get-MtTestSchema {
    <#
    .SYNOPSIS
    Returns the [MaesterTest] schema table (assets/MaesterTestSchema.psd1). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    if (-not $script:__MtTestSchema) {
        $script:__MtTestSchema = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterTestSchema.psd1')
    }
    $script:__MtTestSchema
}

function Get-MtServiceRegistry {
    <#
    .SYNOPSIS
    Returns the service registry (assets/MaesterServiceRegistry.psd1). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    if (-not $script:__MtServiceRegistry) {
        $script:__MtServiceRegistry = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterServiceRegistry.psd1')
    }
    $script:__MtServiceRegistry
}

function Get-MtParameterKindRegistry {
    <#
    .SYNOPSIS
    Returns the parameter-kind registry (assets/MaesterParameterKinds.psd1). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    if (-not $script:__MtParameterKinds) {
        $script:__MtParameterKinds = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterParameterKinds.psd1')
    }
    $script:__MtParameterKinds
}

function Resolve-MtServiceName {
    <#
    .SYNOPSIS
    Returns the registry name of a service name or alias, case-insensitively, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter()] [hashtable] $Registry = (Get-MtServiceRegistry)
    )
    foreach ($key in $Registry.Services.Keys) {
        if ($key -eq $Name) { return $key }
        if (@($Registry.Services[$key].Aliases) -contains $Name) { return $key }
    }
    $null
}
