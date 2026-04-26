function Test-MtAdRootDseSynchronizedStatus {
    <#
    .SYNOPSIS
    Checks the Root DSE synchronization status.

    .DESCRIPTION
    The Root DSE (Directory Service Agent) represents the top of the directory
    tree and provides information about the directory server. The isSynchronized
    attribute indicates whether the directory server has completed its initial
    synchronization with replication partners.

    A value of TRUE indicates the server is fully synchronized.
    A value of FALSE indicates synchronization is still in progress.

    This is important for:
    - Ensuring directory consistency across domain controllers
    - Verifying replication health
    - Troubleshooting authentication issues

    .EXAMPLE
    Test-MtAdRootDseSynchronizedStatus

    Returns $true if Root DSE data is accessible and server is synchronized.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdRootDseSynchronizedStatus
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $rootDse = $adState.RootDSE
    $isSynchronized = $rootDse.isSynchronized

    $testResult = $isSynchronized -eq $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Root DSE Synchronized | $(if ($isSynchronized) { 'Yes' } else { 'No' }) |`n"
    $result += "| Server DNS Name | $($rootDse.dnsHostName) |`n"
    $result += "| Domain Controller Functionality | $($rootDse.domainControllerFunctionality) |`n"
    $result += "| Forest Functionality | $($rootDse.forestFunctionality) |`n"
    $result += "| Domain Functionality | $($rootDse.domainFunctionality) |`n"

    if ($testResult) {
        $testResultMarkdown = "The Active Directory Root DSE is synchronized. The domain controller has completed initial replication.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The Active Directory Root DSE is NOT synchronized. The domain controller may still be completing initial replication.`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


