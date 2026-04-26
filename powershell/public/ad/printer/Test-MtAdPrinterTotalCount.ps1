function Test-MtAdPrinterTotalCount {
    <#
    .SYNOPSIS
    Counts the total number of printers published in Active Directory.

    .DESCRIPTION
    This test retrieves the count of printers that have been published to Active Directory.
    Published printers are shared printers that are advertised in the directory, making them
    discoverable by users and computers in the domain. This provides visibility into the
    printing infrastructure and helps identify potential security considerations related
    to printer publishing.

    .EXAMPLE
    Test-MtAdPrinterTotalCount

    Returns $true if printer data is accessible, $false otherwise.
    The test result includes the total count of published printers.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdPrinterTotalCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $printers = $adState.Printers

    # Count total printers
    $printerCount = ($printers | Measure-Object).Count

    # Test passes if we successfully retrieved printer data
    $testResult = $null -ne $printers

    # Generate markdown results
    if ($testResult) {
        # Get additional printer details if available
        $printersWithLocation = ($printers | Where-Object { $_.Location -and $_.Location -ne "" } | Measure-Object).Count
        $printersWithDescription = ($printers | Where-Object { $_.Description -and $_.Description -ne "" } | Measure-Object).Count

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Published Printers | $printerCount |`n"
        $result += "| Printers with Location | $printersWithLocation |`n"
        $result += "| Printers with Description | $printersWithDescription |`n`n"

        if ($printerCount -gt 0 -and $printers.Count -gt 0) {
            $result += "**Published Printers:**`n`n"
            $result += "| Printer Name | Location |`n"
            $result += "| --- | --- |`n"

            foreach ($printer in ($printers | Select-Object -First 10)) {
                $printerName = if ($printer.Name) { $printer.Name } else { "Unknown" }
                $location = if ($printer.Location) { $printer.Location } else { "Not specified" }
                $result += "| $printerName | $location |`n"
            }

            if ($printerCount -gt 10) {
                $result += "| ... | ... |`n"
                $result += "| *($($printerCount - 10) more printers)* | |`n"
            }
        }

        $testResultMarkdown = "Active Directory contains $printerCount published printer(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve printer information from Active Directory. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


