function Resolve-MtDnsRecord {
    <#
    .SYNOPSIS
    Resolves DNS records with consistent results across supported platforms.

    .DESCRIPTION
    Uses Resolve-DnsName on Windows and Resolve-Dns from DnsClient-PS on other platforms.
    A successful query with no answers has Status Success and an empty Answers array.

    .PARAMETER Name
    The DNS name to query.

    .PARAMETER Type
    The DNS record type to query.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'TXT')]
        [string]$Type
    )

    $result = [pscustomobject]@{
        Name    = $Name
        Type    = $Type
        Status  = 'Success'
        Answers = [object[]]@()
        Error   = $null
    }
    $answers = @()

    if ($IsWindows) {
        try {
            $response = Resolve-DnsName -Name $Name -Type $Type -ErrorAction Stop
            $answers = @($response | Where-Object { $_.Section -eq 'Answer' -and $_.Type -eq $Type })
        } catch [System.Management.Automation.CommandNotFoundException] {
            $result.Status = 'NotAvailable'
            $result.Error = 'Unsupported platform, Resolve-DnsName not available'
            return $result
        } catch {
            if ($_.FullyQualifiedErrorId -like 'DNS_ERROR_RCODE_NAME_ERROR*') {
                $result.Status = 'NXDomain'
            } elseif ($_.FullyQualifiedErrorId -notlike 'DNS_INFO_NO_RECORDS*') {
                $result.Status = 'Error'
                $result.Error = "$_"
            }
            return $result
        }
    } else {
        if (-not (Get-Command -Name 'Resolve-Dns' -ErrorAction SilentlyContinue)) {
            $result.Status = 'NotAvailable'
            $result.Error = 'Missing dependency, Resolve-Dns not available'
            return $result
        }

        try {
            $response = Resolve-Dns -Query $Name -QueryType $Type -ErrorAction Stop
            if ($response.HasError) {
                if ("$($response.Header.ResponseCode)" -eq 'NotExistentDomain') {
                    $result.Status = 'NXDomain'
                } else {
                    $result.Status = 'Error'
                    $result.Error = $response.ErrorMessage
                }
                return $result
            }
            $answers = @($response.Answers | Where-Object { "$($_.RecordType)" -eq $Type })
        } catch {
            $result.Status = 'Error'
            $result.Error = "$_"
            return $result
        }
    }

    foreach ($answer in $answers) {
        $value = $null
        $preference = $null
        switch ($Type) {
            'TXT' {
                if ($answer.PSObject.Properties['Strings']) {
                    $value = @($answer.Strings) -join ''
                } elseif ($answer.PSObject.Properties['Text']) {
                    $value = @($answer.Text) -join ''
                }
            }
            'MX' {
                if ($answer.PSObject.Properties['NameExchange']) {
                    $value = $answer.NameExchange
                } elseif ($answer.PSObject.Properties['Exchange']) {
                    $value = $answer.Exchange
                }
                if ($answer.PSObject.Properties['Preference']) {
                    $preference = $answer.Preference
                }
            }
            'CNAME' {
                foreach ($propertyName in 'NameHost', 'CanonicalName', 'CName', 'HostName') {
                    if ($answer.PSObject.Properties[$propertyName]) {
                        $value = $answer.PSObject.Properties[$propertyName].Value
                        break
                    }
                }
            }
            { $_ -in 'A', 'AAAA' } {
                foreach ($propertyName in 'IPAddress', 'IPv4Address', 'IPv6Address', 'Address') {
                    if ($answer.PSObject.Properties[$propertyName]) {
                        $value = $answer.PSObject.Properties[$propertyName].Value
                        break
                    }
                }
            }
        }

        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            $result.Status = 'Error'
            $result.Error = "The DNS resolver returned an unusable $Type answer for $Name."
            $result.Answers = [object[]]@()
            return $result
        }

        $result.Answers += [pscustomobject]@{
            Value      = [string]$value
            Preference = $preference
        }
    }

    return $result
}