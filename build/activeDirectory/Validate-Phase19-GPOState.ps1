[CmdletBinding()]
param()

$scriptName = Split-Path -Leaf $PSCommandPath
Write-Warning "$scriptName has been retired. It depended on legacy Windows modules that are no longer part of the supported Active Directory runner workflow."
Write-Host 'Use azure-lab/Test-ADProtocolPrerequisites.ps1 to validate network, TLS, authentication, and remoting prerequisites.' -ForegroundColor Yellow
Write-Host 'Use Run-ADTests-And-CopyReports.ps1 or Invoke-ADSingleTargetRun.ps1 for one isolated endpoint per Connect-Maester / Invoke-Maester cycle.' -ForegroundColor Yellow
throw "$scriptName is retired. See build/activeDirectory/README-ADTestRunner.md for the protocol-based workflow."
