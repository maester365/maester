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
        foreach ($InputObject in $InputObjects) {
            $QueryString = New-Object System.Text.StringBuilder
            if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary] -or $InputObject.GetType().FullName.StartsWith('System.Collections.Generic.Dictionary')) {
                foreach ($Item in $InputObject.GetEnumerator()) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }
                    [string] $ParameterName = $Item.Key
                    if ($EncodeParameterNames) { $ParameterName = [System.Net.WebUtility]::UrlEncode($ParameterName) }
                    [void]$QueryString.AppendFormat('{0}={1}', $ParameterName, [System.Net.WebUtility]::UrlEncode($Item.Value))
                }
            }
            elseif ($InputObject -is [object] -and $InputObject -isnot [ValueType]) {
                foreach ($Item in ($InputObject | Get-Member -MemberType Property, NoteProperty)) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }
                    [string] $ParameterName = $Item.Name
                    if ($EncodeParameterNames) { $ParameterName = [System.Net.WebUtility]::UrlEncode($ParameterName) }
                    [void]$QueryString.AppendFormat('{0}={1}', $ParameterName, [System.Net.WebUtility]::UrlEncode($InputObject.($Item.Name)))
                }
            }
            else {
                ## Non-Terminating Error
                $Exception = New-Object ArgumentException -ArgumentList ('Cannot convert input of type {0} to query string.' -f $InputObject.GetType())
                Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::ParserError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'ConvertQueryStringFailureTypeNotSupported' -TargetObject $InputObject
                continue
            }

            Write-Output $QueryString.ToString()
        }
    }
}
