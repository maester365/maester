<#
.SYNOPSIS
Retrieves an Azure access token for a specified resource using the Azure CLI.

.DESCRIPTION
The `Get-MtAccessTokenUsingCli` function retrieves an Azure access token for a specified resource by invoking the Azure CLI.
The token can be returned as a plain string or as a secure string, depending on the `-AsSecureString` parameter.
Serves as a drop-in replacement of Get-AzAccessToken.

.PARAMETER Resource
The Azure resource for which the access token is requested. This parameter is mandatory.

.PARAMETER AsSecureString
If specified, the access token is returned as a secure string. This parameter is optional.

.EXAMPLE
# Retrieve an access token as a plain string
$token = Get-MtAccessTokenUsingCli -ResourceUrl "https://management.azure.com/"

.EXAMPLE
# Retrieve an access token as a secure string
$secureToken = Get-MtAccessTokenUsingCli -ResourceUrl "https://management.azure.com/" -AsSecureString

.NOTES
This function requires the Azure CLI to be installed and authenticated with the appropriate Azure account.
#>

function Get-MtAccessTokenUsingCli {
    [OutputType([string], [SecureString])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceUrl,

        [Parameter(Mandatory = $false)]
        [switch]$AsSecureString
    )

    Write-Host "Getting access token for resource: $ResourceUrl"
    # Construct the command to get the access token using Azure CLI
    $command = "az account get-access-token --resource $ResourceUrl --query accessToken -o tsv"

    # Execute the command and capture the output
    try {
        $accessToken = Invoke-Expression -Command $command
        if ($AsSecureString) {
            $accessToken = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
        }
        return $accessToken
    } catch {
        Write-Error "Failed to get access token: $_"
    }
}