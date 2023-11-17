<#
.SYNOPSIS
    Convert Query String to object.
.EXAMPLE
    PS C:\>ConvertFrom-QueryString '?name=path/file.json&index=10'
    Convert query string to object.
.EXAMPLE
    PS C:\>'name=path/file.json&index=10' | ConvertFrom-QueryString -AsHashtable
    Convert query string to hashtable.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/Utility.PS
#>
function ConvertFrom-QueryString {
    [CmdletBinding()]
    [OutputType([psobject])]
    [OutputType([hashtable])]
    param (
        # Value to convert
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputStrings,
        # URL decode parameter names
        [Parameter(Mandatory = $false)]
        [switch] $DecodeParameterNames,
        # Converts to hash table object
        [Parameter(Mandatory = $false)]
        [switch] $AsHashtable
    )

    process {
        foreach ($InputString in $InputStrings) {
            if ($AsHashtable) { [hashtable] $OutputObject = @{ } }
            else { [psobject] $OutputObject = New-Object psobject }

            if ($InputString[0] -eq '?') { $InputString = $InputString.Substring(1) }
            [string[]] $QueryParameters = $InputString.Split('&')
            foreach ($QueryParameter in $QueryParameters) {
                [string[]] $QueryParameterPair = $QueryParameter.Split('=')
                if ($DecodeParameterNames) { $QueryParameterPair[0] = [System.Net.WebUtility]::UrlDecode($QueryParameterPair[0]) }
                if ($OutputObject -is [hashtable]) {
                    $OutputObject.Add($QueryParameterPair[0], [System.Net.WebUtility]::UrlDecode($QueryParameterPair[1]))
                }
                else {
                    $OutputObject | Add-Member $QueryParameterPair[0] -MemberType NoteProperty -Value ([System.Net.WebUtility]::UrlDecode($QueryParameterPair[1]))
                }
            }
            Write-Output $OutputObject
        }
    }

}
