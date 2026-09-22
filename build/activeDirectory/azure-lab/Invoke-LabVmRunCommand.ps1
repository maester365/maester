<#
.SYNOPSIS
    Invokes Azure VM Run Command with enhanced diagnostics following the vm-guest-management skill patterns.

.DESCRIPTION
    This script wraps Azure VM Run Command execution with the patterns from the
    microsoft-skills vm-guest-management skill (https://github.com/soulemike/microsoft-skills).

    Key improvements over raw 'az vm run-command invoke':
    - Inspects instanceView for executionState, exitCode, output, and error
    - Distinguishes provisioning success from guest script success
    - Supports managed Run Command resources for production scenarios
    - Better timeout handling and diagnostics for credential-sensitive operations

    This wrapper is particularly valuable for AD DS operations where credential
    delegation issues require detailed error diagnostics.

.PARAMETER ResourceGroupName
    Azure resource group containing the target VM.

.PARAMETER VmName
    Name of the target virtual machine.

.PARAMETER ScriptString
    Inline PowerShell script to execute.

.PARAMETER ScriptPath
    Path to a local script file to upload and execute.

.PARAMETER RunCommandName
    Optional name for managed Run Command resource.

.PARAMETER TimeoutInSeconds
    Guest execution timeout. Default: 1800 (30 minutes).

.PARAMETER TreatFailureAsDeploymentFailure
    When specified, provisioning failure throws an exception.

.PARAMETER OutputBlobUri
    SAS URI for capturing stdout to blob storage.

.PARAMETER ErrorBlobUri
    SAS URI for capturing stderr to blob storage.

.PARAMETER Parameters
    Hashtable of parameters to pass to the script.

.EXAMPLE
    ./Invoke-LabVmRunCommand.ps1 `
        -ResourceGroupName 'RG_5100_MiSoule_2' `
        -VmName 'MiSouleDC03' `
        -ScriptString 'Install-ADDSDomain -ParentDomainName misoule02.local ...' `
        -TimeoutInSeconds 3600

    Executes a child domain promotion with extended timeout and detailed diagnostics.

.EXAMPLE
    $result = ./Invoke-LabVmRunCommand.ps1 `
        -ResourceGroupName 'RG_5100_MiSoule_2' `
        -VmName 'MiSouleDC02' `
        -ScriptString 'Get-ADRootDSE | Select-Object dnsHostName' `
        -RunCommandName 'ad-diagnostics'

    if ($result.ExecutionState -ne 'Succeeded' -or $result.ExitCode -ne 0) {
        throw "Guest execution failed: $($result.Error)"
    }
    Write-Host $result.Output

.NOTES
    Based on patterns from: https://github.com/soulemike/microsoft-skills/tree/main/skills/vm-guest-management

    Critical pattern: Always inspect instanceView, not just provisioningState.
    ARM provisioning success does NOT guarantee guest script success.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$VmName,

    [Parameter(Mandatory, ParameterSetName = 'Inline')]
    [string]$ScriptString,

    [Parameter(Mandatory, ParameterSetName = 'File')]
    [string]$ScriptPath,

    [Parameter()]
    [string]$RunCommandName,

    [Parameter()]
    [ValidateRange(1, 5400)]
    [int]$TimeoutInSeconds = 1800,

    [Parameter()]
    [switch]$TreatFailureAsDeploymentFailure,

    [Parameter()]
    [string]$OutputBlobUri,

    [Parameter()]
    [string]$ErrorBlobUri,

    [Parameter()]
    [hashtable]$Parameters = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandAvailable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CommandName)
    return $null -ne (Get-Command -Name $CommandName -ErrorAction SilentlyContinue)
}

function Invoke-AzCliWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter()][switch]$ExpectJson,
        [Parameter()][int]$MaxRetries = 3
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = (Get-Command -Name 'az' -CommandType Application).Source
            $psi.Arguments = ($Arguments | ForEach-Object {
                if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
            }) -join ' '
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $proc = [System.Diagnostics.Process]::Start($psi)
            $output = $proc.StandardOutput.ReadToEnd()
            $errorOutput = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()

            if ($proc.ExitCode -ne 0) {
                throw "Azure CLI exited with code $($proc.ExitCode): $errorOutput"
            }

            if ($ExpectJson.IsPresent -and $output) {
                return $output | ConvertFrom-Json
            }
            return $output
        }
        catch {
            $lastError = $_
            if ($attempt -lt $MaxRetries) {
                Write-Warning "Attempt $attempt failed: $($_.Exception.Message). Retrying in $($attempt * 5) seconds..."
                Start-Sleep -Seconds ($attempt * 5)
            }
        }
    }
    throw $lastError
}

function Get-RunCommandInstanceView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$VmName,
        [Parameter(Mandatory)][string]$RunCommandName
    )

    $arguments = @(
        'vm', 'run-command', 'show'
        '--resource-group', $ResourceGroupName
        '--name', $VmName
        '--run-command-name', $RunCommandName
        '--output', 'json'
    )

    return Invoke-AzCliWithRetry -Arguments $arguments -ExpectJson
}

function Wait-RunCommandCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$VmName,
        [Parameter(Mandatory)][string]$RunCommandName,
        [Parameter()][int]$TimeoutInSeconds = 1800
    )

    $deadline = (Get-Date).AddSeconds($TimeoutInSeconds + 120)
    $pollInterval = 5

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $pollInterval

        try {
            $instanceView = Get-RunCommandInstanceView -ResourceGroupName $ResourceGroupName -VmName $VmName -RunCommandName $RunCommandName

            if ($instanceView.instanceView -and $instanceView.instanceView.executionState) {
                $state = $instanceView.instanceView.executionState
                Write-Verbose "Run Command '$RunCommandName' state: $state"

                if ($state -in @('Succeeded', 'Failed', 'Canceled')) {
                    return $instanceView.instanceView
                }
            }
            elseif ($instanceView.provisioningState -in @('Succeeded', 'Failed', 'Canceled')) {
                # Fallback to provisioning state if instanceView not yet available
                Write-Verbose "Run Command '$RunCommandName' provisioning state: $($instanceView.provisioningState)"
                if ($instanceView.provisioningState -ne 'Succeeded') {
                    return @{
                        executionState = $instanceView.provisioningState
                        exitCode = 1
                        output = $null
                        error = "Provisioning failed: $($instanceView.provisioningState)"
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to poll run command status: $($_.Exception.Message)"
        }
    }

    throw "Run Command '$RunCommandName' did not complete within timeout ($TimeoutInSeconds seconds)."
}

# Main execution
try {
    if (-not (Test-CommandAvailable -CommandName 'az')) {
        throw 'Azure CLI (az) is required but was not found in PATH.'
    }

    # Determine script content
    $scriptContent = if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path -Path $ScriptPath -PathType Leaf)) {
            throw "Script file not found: $ScriptPath"
        }
        Get-Content -Path $ScriptPath -Raw
    }
    else {
        $ScriptString
    }

    # Generate run command name if not provided
    $effectiveRunCommandName = if ($RunCommandName) {
        $RunCommandName
    }
    else {
        'lab-run-{0}' -f (Get-Date -Format 'yyyyMMddHHmmss')
    }

    Write-Verbose "Executing run command '$effectiveRunCommandName' on VM '$VmName'"

    # Build base arguments for managed run command
    $arguments = @(
        'vm', 'run-command', 'create'
        '--resource-group', $ResourceGroupName
        '--vm-name', $VmName
        '--run-command-name', $effectiveRunCommandName
        '--script', $scriptContent
        '--timeout-in-seconds', ([string]$TimeoutInSeconds)
        '--output', 'json'
    )

    if ($TreatFailureAsDeploymentFailure.IsPresent) {
        $arguments += '--treat-failure-as-deployment-failure'
    }

    if ($OutputBlobUri) {
        $arguments += '--output-blob-uri'
        $arguments += $OutputBlobUri
    }

    if ($ErrorBlobUri) {
        $arguments += '--error-blob-uri'
        $arguments += $ErrorBlobUri
    }

    # Add parameters if provided
    foreach ($paramName in $Parameters.Keys) {
        $arguments += '--parameters'
        $arguments += ('{0}={1}' -f $paramName, $Parameters[$paramName])
    }

    Write-Verbose "Creating managed run command resource..."
    $createResult = Invoke-AzCliWithRetry -Arguments $arguments -ExpectJson
    Write-Verbose "Run command resource created. Waiting for execution..."

    # Wait for completion and get detailed results
    $instanceView = Wait-RunCommandCompletion `
        -ResourceGroupName $ResourceGroupName `
        -VmName $VmName `
        -RunCommandName $effectiveRunCommandName `
        -TimeoutInSeconds $TimeoutInSeconds

    # Build result object
    $result = [pscustomobject][ordered]@{
        RunCommandName     = $effectiveRunCommandName
        VmName             = $VmName
        ResourceGroupName  = $ResourceGroupName
        ExecutionState     = $instanceView.executionState
        ExitCode           = if ($null -ne $instanceView.exitCode) { $instanceView.exitCode } else { -1 }
        Output             = $instanceView.output
        Error              = $instanceView.error
        StartTime          = $instanceView.startTime
        EndTime            = $instanceView.endTime
        ProvisioningState  = $createResult.provisioningState
        Duration           = if ($instanceView.startTime -and $instanceView.endTime) {
            ([datetime]$instanceView.endTime) - ([datetime]$instanceView.startTime)
        }
        else { $null }
    }

    # Output result
    if ($result.ExecutionState -eq 'Succeeded' -and $result.ExitCode -eq 0) {
        Write-Verbose "Run command completed successfully."
    }
    else {
        Write-Warning "Run command completed with issues: State=$($result.ExecutionState), ExitCode=$($result.ExitCode)"
        if ($result.Error) {
            Write-Warning "Error output: $($result.Error)"
        }
    }

    return $result
}
catch {
    $message = "Failed to execute run command on VM '$VmName'. $($_.Exception.Message)"
    throw [System.InvalidOperationException]::new($message, $_.Exception)
}
