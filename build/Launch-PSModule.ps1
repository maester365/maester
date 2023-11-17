param (
    # Module to Launch
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = '.\src\*.psd1',
    # ScriptBlock to Execute After Module Import
    [Parameter(Mandatory = $false)]
    [scriptblock] $PostImportScriptBlock,
    # Paths to PowerShell Executables
    [Parameter(Mandatory = $false)]
    [string[]] $PowerShellPaths = @(
        'pwsh'
        #'powershell'
        #'D:\Software\PowerShell-6.2.4-win-x64\pwsh.exe'
    ),
    # Import Module into the same session
    [Parameter(Mandatory = $false)]
    [switch] $NoNewWindow #= $true
)

## Restore Module Dependencies
$PSModuleCacheDirectory = &$PSScriptRoot\Restore-PSModuleDependencies.ps1 -ModuleManifestPath $ModuleManifestPath #-OutputDirectory $OutputDirectory.FullName

## Launch PSModule
if ($NoNewWindow) {
    Import-Module $ModuleManifestPath -PassThru -Force
    if ($PostImportScriptBlock) { Invoke-Command -ScriptBlock $PostImportScriptBlock -NoNewScope }
}
else {
    [scriptblock] $ScriptBlock = {
        param ([string]$ModulePath, [string]$PSModuleCacheDirectory, [scriptblock]$PostImportScriptBlock)
        ## Reset PSModulePath environment variable to default value because starting powershell.exe from pwsh.exe (or vice versa) will inherit environment variables for the wrong version of PowerShell.
        $PSModulePathDefault = [System.Management.Automation.ModuleIntrinsics]::GetModulePath($null, [System.Environment]::GetEnvironmentVariable('PSMODULEPATH', [EnvironmentVariableTarget]::Machine), [System.Environment]::GetEnvironmentVariable('PSMODULEPATH', [EnvironmentVariableTarget]::User))
        [Environment]::SetEnvironmentVariable("PSMODULEPATH", $PSModulePathDefault)
        ## Add PSModuleCacheDirectory to PSModulePath environment variable
        if (!$env:PSModulePath.Contains($PSModuleCacheDirectory)) { $env:PSModulePath += '{0}{1}' -f [IO.Path]::PathSeparator, $PSModuleCacheDirectory }
        ## Import Module and Execute Post-Import ScriptBlock
        Import-Module $ModulePath -PassThru
        Invoke-Command -ScriptBlock $PostImportScriptBlock -NoNewScope
    }
    $strScriptBlock = 'Invoke-Command -ScriptBlock {{ {0} }} -ArgumentList {1}, {2}, {{ {3} }}' -f $ScriptBlock, $ModuleManifestPath, $PSModuleCacheDirectory, $PostImportScriptBlock
    #$strScriptBlock = 'Import-Module {0} -PassThru' -f $ModuleManifestPath

    foreach ($Path in $PowerShellPaths) {
        if ($Path -eq 'wsl') {
            Start-Process $Path -ArgumentList ('pwsh' , '-NoExit', '-NoProfile', '-EncodedCommand', [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($strScriptBlock)))
        }
        else {
            Start-Process $Path -ArgumentList ('-NoExit', '-NoProfile', '-EncodedCommand', [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($strScriptBlock)))
        }
    }
}
