function Register-MtArgumentCompleter {
    <#
    .SYNOPSIS
    Registers Tab completion for the parameters in Get-MtArgumentCompleterTable. Called once when the module loads.

    .DESCRIPTION
    The completer is created here, inside the module, so it runs in the module's scope and reaches its private
    functions and caches. A script block in an [ArgumentCompleter()] attribute does not: it runs outside the
    module and cannot call them. Importing the module again registers the completers again, replacing these.
    #>
    [CmdletBinding()]
    param()

    # $args: command name, parameter name, word to complete, command AST, fake bound parameters.
    $completer = { Get-MtArgumentCompletion -CommandName $args[0] -ParameterName $args[1] -WordToComplete $args[2] -FakeBoundParameters $args[4] }
    foreach ($row in Get-MtArgumentCompleterTable) {
        Register-ArgumentCompleter -CommandName $row.Command -ParameterName $row.Parameter -ScriptBlock $completer
    }
}
