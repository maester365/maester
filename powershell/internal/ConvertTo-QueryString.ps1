<#
.SYNOPSIS
    Convert Hashtable to Query String.
.EXAMPLE
    PS C:\>ConvertTo-QueryString @{ name = 'path/file.json'; index = 10 }
    Convert hashtable to query string.
.EXAMPLE
    PS C:\>[ordered]@{ title = 'convert&prosper'; id = [guid]'352182e6-9ab0-4115-807b-c36c88029fa4' } | ConvertTo-QueryString
    Convert ordered dictionary to query string.
.INPUTS
    System.Collections.Hashtable
.LINK
    https://github.com/jasoth/Utility.PS
#>
function ConvertTo-QueryString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Value to convert
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObjects,
        # URL encode parameter names
        [Parameter(Mandatory = $false)]
        [switch] $EncodeParameterNames
    )

    process {
        if ($null -eq $InputObjects) {
            Write-Output ''
            return
        }
        
        foreach ($InputObject in @($InputObjects)) {
            if ($null -eq $InputObject) {
                Write-Output ''
                continue
            }

            $QueryString = New-Object System.Text.StringBuilder

            if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary] -or ($null -ne $InputObject.GetType().GetInterface('System.Collections.Generic.IDictionary`2'))) {
                foreach ($Item in $InputObject.GetEnumerator()) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }

                    [string] $ParameterName = $Item.Key
                    if ($EncodeParameterNames) { $ParameterName = [System.Net.WebUtility]::UrlEncode($ParameterName) }

                    ## Convert null values to empty string
                    $value = if ($null -eq $Item.Value) { '' } else { $Item.Value.ToString() }
                    [void]$QueryString.AppendFormat('{0}={1}', $ParameterName, [System.Net.WebUtility]::UrlEncode($value))
                }
            } elseif ($InputObject -is [object] -and $InputObject -isnot [ValueType]) {
                $properties = $InputObject | Get-Member -MemberType Property, NoteProperty
                foreach ($Item in $properties) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }

                    [string] $ParameterName = $Item.Name
                    if ($EncodeParameterNames) { $ParameterName = [System.Net.WebUtility]::UrlEncode($ParameterName) }

                    ## Convert null property values to empty string
                    $propertyValue = $InputObject.($Item.Name)
                    $value = if ($null -eq $propertyValue) { '' } else { $propertyValue.ToString() }
                    [void]$QueryString.AppendFormat('{0}={1}', $ParameterName, [System.Net.WebUtility]::UrlEncode($value))
                }
            } else {
                ## Non-terminating error
                $Exception = New-Object ArgumentException -ArgumentList ('Cannot convert input of type {0} to query string. Supported types: Hashtable, OrderedDictionary, Dictionary, or objects with properties.' -f $InputObject.GetType())
                Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::ParserError) -CategoryActivity $MyInvocation.MyCommand.Name -ErrorId 'ConvertQueryStringFailureTypeNotSupported' -TargetObject $InputObject
                continue
            }

            Write-Output $QueryString.ToString()
        }
    }
}
