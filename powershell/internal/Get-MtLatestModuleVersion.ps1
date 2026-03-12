function Get-MtLatestModuleVersion {
    <#
    .SYNOPSIS
    Retrieves the latest stable version (non-prerelease) of a module from the PowerShell Gallery.
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $Name = 'Maester',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int] $TimeoutSec = 10
    )

    function ConvertTo-StableVersion {
        <#
        .SYNOPSIS
        Converts an input version string to a [version] object if it's a stable version.

        .DESCRIPTION
        ConvertTo-StableVersion attempts to parse the input version and returns a [version] object if it's a stable version.
        If the input is null, empty, or contains a prerelease suffix (indicated by a hyphen), it returns $null.
        This ensures that only stable versions are considered when determining the latest module version.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [object] $InputVersion
        )

        if ($null -eq $InputVersion) {
            return $null
        }

        # If the version is null or empty after converting to string, return null.
        $VersionString = [string]$InputVersion
        if ([string]::IsNullOrWhiteSpace($VersionString)) {
            return $null
        }

        # Keep behavior aligned with Find-Module default by ignoring prerelease versions (indicated by a hyphen).
        if ($VersionString -match '-') {
            return $null
        }

        try {
            return [version]$versionString
        } catch {
            Write-Warning "Could not parse version '$versionString': $_"
            return $null
        }
    } # End of ConvertTo-StableVersion

    function Get-LatestVersionFromOData {
        <#
        .SYNOPSIS
        Retrieves the latest stable version (non-prerelease) of a module from the PowerShell Gallery using the OData API.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string] $ModuleName,

            [Parameter()]
            [int] $RequestTimeoutSec = 10
        )

        $escapedModuleName = $ModuleName.Replace("'", "''")
        $uri = "https://www.powershellgallery.com/api/v2/FindPackagesById()?id='$escapedModuleName'&`$filter=IsLatestVersion and not IsPrerelease"
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec $RequestTimeoutSec -ErrorAction Stop

        $xmlNamespaceManager = $null
        if ($response -is [System.Xml.XmlElement] -and $null -ne $response.OwnerDocument) {
            $xmlNamespaceManager = [System.Xml.XmlNamespaceManager]::new($response.OwnerDocument.NameTable)
            $xmlNamespaceManager.AddNamespace('m', 'http://schemas.microsoft.com/ado/2007/08/dataservices/metadata')
            $xmlNamespaceManager.AddNamespace('d', 'http://schemas.microsoft.com/ado/2007/08/dataservices')
        }

        $rawVersion = $null
        if ($null -ne $response.properties -and $null -ne $response.properties.Version) {
            $rawVersion = $response.properties.Version
        } elseif ($response -is [System.Xml.XmlElement] -and $null -ne $xmlNamespaceManager) {
            $versionNode = $response.SelectSingleNode('m:properties/d:Version', $xmlNamespaceManager)
            if ($null -ne $versionNode) {
                $rawVersion = $versionNode.InnerText
            }
        }

        $stableVersion = ConvertTo-StableVersion -InputVersion $rawVersion
        if ($null -ne $stableVersion) {
            return $stableVersion
        } else {
            Write-Verbose "No stable version found in OData response for '$ModuleName'. Raw version value: '$rawVersion'"
            return $null
        }
    } # End of Get-LatestVersionFromOData

    function Get-LatestVersionFromPSResourceGet {
        param(
            [Parameter(Mandatory = $true)]
            [string] $ModuleName
        )

        $resource = Find-PSResource -Name $ModuleName -ErrorAction Stop | Select-Object -First 1
        return ConvertTo-StableVersion -InputVersion $resource.Version
    } # End of Get-LatestVersionFromPSResourceGet

    function Get-LatestVersionFromPowerShellGet {
        param(
            [Parameter(Mandatory = $true)]
            [string] $ModuleName
        )

        # NuGet provider readiness check avoids interactive provider bootstrap prompts in PS7 environments.
        $nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
        if ($null -eq $nugetProvider) {
            Write-Verbose 'Skipping Find-Module fallback because NuGet provider is not installed.'
            return $null
        }

        $module = Find-Module -Name $ModuleName -ErrorAction Stop
        return ConvertTo-StableVersion -InputVersion $module.Version
    } # End of Get-LatestVersionFromPowerShellGet

    # Main logic of Get-MtLatestModuleVersion starts here.

    # Attempt to get the latest version from the OData API first, as it's the most direct source and doesn't rely on installed modules.
    try {
        $ODataVersion = Get-LatestVersionFromOData -ModuleName $Name -RequestTimeoutSec $TimeoutSec
        if ($null -ne $ODataVersion) {
            return $ODataVersion
        }
    } catch {
        Write-Verbose "Unable to get latest version from PowerShell Gallery OData API for '$Name': $_"
    }

    # If OData lookup fails, fall back to PSResourceGet if available, then PowerShellGet, as these may have cached data even when the API is unreachable.
    if (Get-Command 'Find-PSResource' -ErrorAction SilentlyContinue) {
        try {
            return Get-LatestVersionFromPSResourceGet -ModuleName $Name
        } catch {
            Write-Verbose "Unable to get latest version using Find-PSResource for '$Name': $_"
        }
    }

    # As a last resort, attempt to get the latest version using PowerShellGet's Find-Module, but only if the NuGet provider is available to avoid unnecessary errors and delays.
    if (Get-Command 'Find-Module' -ErrorAction SilentlyContinue) {
        try {
            return Get-LatestVersionFromPowerShellGet -ModuleName $Name
        } catch {
            Write-Verbose "Unable to get latest version using Find-Module for '$Name': $_"
        }
    }

    # If all methods fail, return null to indicate that the latest version could not be determined.
    return $null
}
