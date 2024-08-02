<#
.SYNOPSIS
    Get license information for known M365 Products

.DESCRIPTION
    This function retrieves the license information for known M365 Product SKUs using a list Microsoft maintains.

.EXAMPLE
    Update-MtLicenseCache

.LINK
    https://maester.dev/docs/commands/Update-MtLicenseCache
#>
function Update-MtLicenseCache {
    [OutputType([System.Void])]
    [CmdletBinding()]
    param ()

    process {
        try{
            Write-Verbose "Attempting License Cache Update"
            $csv = Invoke-RestMethod -Uri "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv"
        }
        catch{
            Write-Error $_
            exit
        }
        Write-Verbose "Getting hash of downloaded content"
        $hashNew = Get-FileHash -InputStream ([IO.MemoryStream]::new([text.encoding]::UTF8.GetBytes($skus2))) -Algorithm SHA256

        if(Test-Path -Path $env:TEMP\maesterLicenses.csv){
            Write-Verbose "Cache exists"
            $skus = Get-Content $env:TEMP\maesterLicenses.csv
            Write-Verbose "Getting cache hash"
            $hashOld = Get-FileHash -InputStream ([IO.MemoryStream]::new([text.encoding]::UTF8.GetBytes($skus))) -Algorithm SHA256
            if($hashNew.Hash -ne $hashOld.Hash){
                Write-Verbose "Cache does not match download, overwriting"
                $csv|Out-File $env:TEMP\maesterLicenses.csv
                $skus = $csv|ConvertFrom-Csv
            }else{
                Write-Verbose "Cache matches"
                $skus = $skus|ConvertFrom-Csv
            }
        }else{
            Write-Verbose "Cache does not exist, setting cache"
            $csv|Out-File $env:TEMP\maesterLicenses.csv
            $skus = $csv|ConvertFrom-Csv
        }

        Write-Verbose "$(($skus|Measure-Object).Count) SKUs in cache"
        return $null
    }
}