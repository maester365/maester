<#
.SYNOPSIS
    Get license information for known M365 Products

.DESCRIPTION
    This function retrieves the license information for known M365 Product SKUs using a list Microsoft maintains.

.EXAMPLE
    Update-MtLicenseCache

.PARAMETER Force
    Forces the cmdlet to update the cache file

.PARAMETER FileName
    Provides the file name for the cache file in the system temp directory

.LINK
    https://maester.dev/docs/commands/Update-MtLicenseCache
#>
function Update-MtLicenseCache {
    [OutputType([System.Void])]
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = "Low"
    )]

    param (
        [Switch]$Force,
        [String]$FileName="maesterLicenses.csv"
    )

    process {
        if ($Force -and -not $Confirm){
            $ConfirmPreference = "None"
        }

        try{
            Write-Verbose "Attempting License Cache Update"
            $csv = Invoke-RestMethod -Uri "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv"
        }
        catch{
            Write-Error $_
            exit
        }
        Write-Verbose "Getting hash of downloaded content"
        $hashNew = Get-FileHash -InputStream ([IO.MemoryStream]::new([text.encoding]::UTF8.GetBytes($csv))) -Algorithm SHA256

        if(Test-Path -Path $env:TEMP\$FileName){
            Write-Verbose "Cache exists"
            $skus = Get-Content $env:TEMP\$FileName
            Write-Verbose "Getting cache hash"
            $hashOld = Get-FileHash -InputStream ([IO.MemoryStream]::new([text.encoding]::UTF8.GetBytes($skus))) -Algorithm SHA256
            if($hashNew.Hash -ne $hashOld.Hash -and $PSCmdlet.ShouldProcess($FileName)){
                Write-Verbose "Cache does not match download, overwriting"
                $csv|Out-File $env:TEMP\$FileName -Confirm:$false
                $skus = $csv|ConvertFrom-Csv
            }else{
                Write-Verbose "Cache matches"
                $skus = $skus|ConvertFrom-Csv
            }
        }else{
            Write-Verbose "Cache does not exist, setting cache"
            if($PSCmdlet.ShouldProcess($FileName)){
                $csv|Out-File $env:TEMP\$FileName -Confirm:$false
            }
            $skus = $csv|ConvertFrom-Csv
        }

        Write-Verbose "$(($skus|Measure-Object).Count) SKUs in cache"
        return $null
    }
}