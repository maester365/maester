function Get-MtShimCommand {
    <#
    .SYNOPSIS
    Returns the command a test function returns when its whole body is one return of one Test-Mt* command.

    .DESCRIPTION
    A benchmark shim is a test whose body is `return <another test's function>` (AGENTS.md, "Reviewing a test
    for duplicates"). This returns that command's name, or $null when the body is anything else. Whether the
    command is another test's function is decided by Get-MtNativeTestInventory, which knows the other tests.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [System.Management.Automation.Language.FunctionDefinitionAst] $Function
    )

    $body = $Function.Body
    if ($body.BeginBlock -or $body.ProcessBlock -or -not $body.EndBlock) { return $null }
    $statements = @($body.EndBlock.Statements)
    if ($statements.Count -ne 1 -or $statements[0] -isnot [System.Management.Automation.Language.ReturnStatementAst]) { return $null }
    $pipeline = $statements[0].Pipeline
    if ($pipeline -isnot [System.Management.Automation.Language.PipelineAst] -or $pipeline.PipelineElements.Count -ne 1) { return $null }
    $command = $pipeline.PipelineElements[0]
    if ($command -isnot [System.Management.Automation.Language.CommandAst]) { return $null }
    $name = $command.GetCommandName()
    if ($name -like 'Test-Mt*') { $name } else { $null }
}
