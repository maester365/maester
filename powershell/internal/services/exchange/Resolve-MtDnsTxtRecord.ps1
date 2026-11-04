function Resolve-MtDnsTxtRecord {
    <#
    .SYNOPSIS
    Returns the TXT records published at a DNS name, without filtering them.

    .DESCRIPTION
    Uses Resolve-DnsName on Windows and Resolve-Dns from the DnsClient-PS module on macOS and Linux. Each TXT
    record is returned as one string: a record that DNS splits into several character strings is joined back
    together with no separator, as ScubaGear's Invoke-RobustDnsTxt does.

    Status is one of:
    - Success: the query was answered. Answers holds the TXT records, and is empty when the name has none.
    - NXDomain: the name does not exist.
    - Error: the query failed. Error holds the message.
    - NotAvailable: no DNS resolver command is available on this platform. Error says which one is missing.

    .PARAMETER Name
    The DNS name to query, for example _dmarc.contoso.com.

    .EXAMPLE
    Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

    Returns the TXT records published at _dmarc.contoso.com.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $result = [pscustomobject]@{
        Name    = $Name
        Status  = 'Success'
        Answers = [string[]]@()
        Error   = $null
    }

    if ($IsWindows) {
        try {
            $response = Resolve-DnsName -Name $Name -Type TXT -ErrorAction Stop
            $result.Answers = [string[]]@($response | Where-Object { $_.Section -eq 'Answer' -and $_.Type -eq 'TXT' } | ForEach-Object { $_.Strings -join '' })
        } catch [System.Management.Automation.CommandNotFoundException] {
            $result.Status = 'NotAvailable'
            $result.Error = 'Unsupported platform, Resolve-DnsName not available'
        } catch {
            Write-Verbose "TXT lookup for $($Name) failed: $_"
            if ($_.FullyQualifiedErrorId -like 'DNS_ERROR_RCODE_NAME_ERROR*') {
                $result.Status = 'NXDomain'
            } elseif ($_.FullyQualifiedErrorId -notlike 'DNS_INFO_NO_RECORDS*') {
                $result.Status = 'Error'
                $result.Error = "$_"
            }
        }
        return $result
    }

    if (-not (Get-Command -Name 'Resolve-Dns' -ErrorAction SilentlyContinue)) {
        Write-Verbose 'For non-Windows platforms, please install the DnsClient-PS module: Install-Module DnsClient-PS -Scope CurrentUser'
        $result.Status = 'NotAvailable'
        $result.Error = 'Missing dependency, Resolve-Dns not available'
        return $result
    }

    try {
        $response = Resolve-Dns -Query $Name -QueryType TXT -ErrorAction Stop
        if ($response.HasError) {
            if ("$($response.Header.ResponseCode)" -eq 'NotExistentDomain') {
                $result.Status = 'NXDomain'
            } else {
                $result.Status = 'Error'
                $result.Error = $response.ErrorMessage
            }
        } else {
            $result.Answers = [string[]]@($response.Answers | Where-Object { "$($_.RecordType)" -eq 'TXT' } | ForEach-Object { $_.Text -join '' })
        }
    } catch {
        Write-Verbose "TXT lookup for $($Name) failed: $_"
        $result.Status = 'Error'
        $result.Error = "$_"
    }
    return $result
}
