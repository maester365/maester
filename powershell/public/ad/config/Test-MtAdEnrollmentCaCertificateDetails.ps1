function Test-MtAdEnrollmentCaCertificateDetails {
    <#
    .SYNOPSIS
    Returns Enterprise CA certificate validity details for AD enrollment.

    .DESCRIPTION
    This test retrieves Enterprise CA objects from the Active Directory configuration and,
    for each CA, attempts to parse the cACertificate property to extract certificate
    validity dates (NotBefore and NotAfter).

    .EXAMPLE
    Test-MtAdEnrollmentCaCertificateDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdEnrollmentCaCertificateDetails
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

    $config = $adState.Configuration
    $enterpriseCAs = $config.EnterpriseCAs
    $hasData = $null -ne $config.EnterpriseCAs

    $rows = @()

    if ($hasData) {
        foreach ($ca in @($enterpriseCAs)) {
            $caName = $ca.Name
            $validFrom = $null
            $validTo = $null
            $parsed = $false

            try {
                $rawCert = $ca.cACertificate
                if ($null -ne $rawCert) {
                    if ($rawCert -is [byte[]]) {
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($rawCert)
                        $validFrom = $cert.NotBefore
                        $validTo = $cert.NotAfter
                        $parsed = $true
                    }
                    elseif ($rawCert -is [string]) {
                        # Attempt to interpret a base64-encoded DER certificate
                        $bytes = $null
                        try {
                            $bytes = [Convert]::FromBase64String($rawCert)
                        } catch {
                            $bytes = $null
                        }
                        if ($bytes) {
                            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($bytes)
                            $validFrom = $cert.NotBefore
                            $validTo = $cert.NotAfter
                            $parsed = $true
                        }
                    }
                }
            } catch {
                # Swallow parsing errors; we will mark validity as unavailable.
                $parsed = $false
            }

            $status = if ($parsed) { 'Yes' } else { 'No' }
            $validFromText = if ($null -ne $validFrom) { $validFrom.ToString('yyyy-MM-dd') } else { 'N/A' }
            $validToText = if ($null -ne $validTo) { $validTo.ToString('yyyy-MM-dd') } else { 'N/A' }

            $rows += [pscustomobject]@{
                'CA Name'             = $caName
                'Certificate Valid From' = $validFromText
                'Certificate Valid To'   = $validToText
                'Certificate Parsed'     = $status
            }
        }
    }

    $testResult = $hasData

    # Generate markdown results
    if ($hasData) {
        $result = "| CA Name | Valid From | Valid To | Parsed |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($row in $rows) {
            $result += "| $($row.'CA Name') | $($row.'Certificate Valid From') | $($row.'Certificate Valid To') | $($row.'Certificate Parsed') |`n"
        }

        $testResultMarkdown = "Active Directory enrollment Enterprise CAs have been analyzed for certificate validity dates.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration data for EnterpriseCAs. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


