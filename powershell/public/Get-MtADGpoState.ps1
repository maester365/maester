function Get-MtADGpoState {
    <#
    .SYNOPSIS
    Collects Active Directory Group Policy state information.

    .DESCRIPTION
    Collects GPO data including GPO objects, reports, permissions, and SYSVOL data.
    Results are cached for the session to avoid repeated queries.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .EXAMPLE
    Get-MtADGpoState

    Returns cached GPO state or collects if not already cached.

    .EXAMPLE
    Get-MtADGpoState -Refresh

    Forces a fresh collection of GPO state data from Active Directory.

    .LINK
    https://maester.dev/docs/commands/Get-MtADGpoState
    #>
    [CmdletBinding()]
    param(
        [switch]$Refresh
    )

    $cacheKey = 'GpoState'

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD GPO State data from Active Directory'

        try {
            $rootDSE = Get-ADRootDSE
            $configurationNC = $rootDSE.configurationNamingContext

            $gpos = Get-GPO -All
            $gpoState = @{
                GPOs            = $gpos
                CollectionTime  = Get-Date
            }

            # Collect and parse GPO reports for security analysis
            try {
                Write-Verbose "Collecting GPO reports for security analysis..."
                $gpoReports = @()
                
                foreach ($gpo in $gpos) {
                    try {
                        # Get GPO report as XML
                        $reportXml = Get-GPOReport -Guid $gpo.Id -ReportType Xml -ErrorAction Stop
                        [xml]$xml = $reportXml
                        
                        $gpoReport = [PSCustomObject]@{
                            GPOId = $gpo.Id
                            GPOName = $gpo.DisplayName
                            DisabledLinks = 0
                            HasVersionMismatch = $false
                            CpasswordFound = $false
                            DefaultPasswordFound = $false
                            HasApplyGroupPolicyAce = $false
                            HasDenyAce = $false
                            EnforcementEnabled = $false
                        }
                        
                        # Check for disabled links in GPO settings
                        if ($xml.GPO.LinksTo) {
                            $links = $xml.GPO.LinksTo | Where-Object { $_.SOMPath }
                            $gpoReport.DisabledLinks = @($links | Where-Object { $_.Enabled -eq 'false' }).Count
                            $gpoReport.EnforcementEnabled = [bool]($links | Where-Object { $_.NoOverride -eq 'true' })
                        }
                        
                        # Check for version mismatch (comparing AD version to SYSVOL version)
                        $adVersion = [int]$xml.GPO.Computer.VersionDirectory + [int]$xml.GPO.User.VersionDirectory
                        $sysvolVersion = [int]$xml.GPO.Computer.VersionSysvol + [int]$xml.GPO.User.VersionSysvol
                        $gpoReport.HasVersionMismatch = ($adVersion -ne $sysvolVersion)
                        
                        # Check for cpassword in GPO settings (indicates insecure password storage)
                        $gpoXmlString = $reportXml.ToString()
                        $gpoReport.CpasswordFound = $gpoXmlString -match 'cpassword|Cpassword|CPASSWORD'
                        
                        # Check for default passwords
                        $gpoReport.DefaultPasswordFound = $gpoXmlString -match 'default.*password|password.*default' -or 
                                                          $gpoXmlString -match 'DefaultPassword|defaultPassword'
                        
                        # Check permissions from SecurityDescriptor
                        if ($xml.GPO.SecurityDescriptor.Permissions.TrusteePermissions) {
                            $permissions = $xml.GPO.SecurityDescriptor.Permissions.TrusteePermissions
                            $gpoReport.HasApplyGroupPolicyAce = [bool]($permissions | Where-Object { 
                                $_.Standard.GPOApply -eq 'true' -and $_.Type -eq 'Allow'
                            })
                            $gpoReport.HasDenyAce = [bool]($permissions | Where-Object { 
                                $_.Type -eq 'Deny'
                            })
                        }
                        
                        $gpoReports += $gpoReport
                    }
                    catch {
                        Write-Verbose "Could not process GPO report for $($gpo.DisplayName): $($_.Exception.Message)"
                    }
                }
                
                $gpoState['GPOReports'] = $gpoReports
                Write-Verbose "Collected $($gpoReports.Count) GPO reports"
            }
            catch {
                Write-Verbose "Could not collect GPO reports: $($_.Exception.Message)"
                $gpoState['GPOReports'] = @()
            }

            # Collect all GPO links from OUs, domain root, and sites
            try {
                Write-Verbose "Collecting GPO links from OUs, domain root, and sites..."
                $allGpoLinks = @()
                
                # Get domain DN for OU and domain root searches
                $domainDN = (Get-ADDomain).DistinguishedName
                
                # Collect GPO links from OUs
                try {
                    $ous = Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName, gPLink
                    foreach ($ou in $ous) {
                        if ($ou.gPLink) {
                            $allGpoLinks += [PSCustomObject]@{
                                DistinguishedName = $ou.DistinguishedName
                                gPLink = $ou.gPLink
                                ObjectClass = 'organizationalUnit'
                            }
                        }
                    }
                    Write-Verbose "Collected GPO links from $($ous.Count) OUs"
                } catch {
                    Write-Verbose "Could not collect OU GPO links: $($_.Exception.Message)"
                }
                
                # Collect GPO links from domain root
                try {
                    $domainRoot = Get-ADObject -Identity $domainDN -Properties DistinguishedName, gPLink
                    if ($domainRoot.gPLink) {
                        $allGpoLinks += [PSCustomObject]@{
                            DistinguishedName = $domainRoot.DistinguishedName
                            gPLink = $domainRoot.gPLink
                            ObjectClass = 'domainDNS'
                        }
                    }
                    Write-Verbose "Collected GPO links from domain root"
                } catch {
                    Write-Verbose "Could not collect domain root GPO links: $($_.Exception.Message)"
                }
                
                # Collect GPO links from sites
                try {
                    $sitesContainer = "CN=Sites,$configurationNC"
                    if ([ADSI]::Exists("LDAP://$sitesContainer")) {
                        $siteObjects = Get-ADObject -Filter * -SearchBase $sitesContainer -Properties DistinguishedName, gPLink, objectClass
                        foreach ($siteObj in $siteObjects) {
                            if ($siteObj.gPLink) {
                                $allGpoLinks += [PSCustomObject]@{
                                    DistinguishedName = $siteObj.DistinguishedName
                                    gPLink = $siteObj.gPLink
                                    ObjectClass = $siteObj.ObjectClass
                                }
                            }
                        }
                        $gpoState['SiteContainers'] = $siteObjects
                        Write-Verbose "Collected GPO links from sites"
                    }
                } catch {
                    Write-Verbose "Could not collect site GPO links: $($_.Exception.Message)"
                    $gpoState['SiteContainers'] = @()
                }
                
                $gpoState['GPOLinks'] = $allGpoLinks
                Write-Verbose "Collected $($allGpoLinks.Count) total GPO link entries"
            }
            catch {
                Write-Verbose "Could not collect GPO link data: $($_.Exception.Message)"
                $gpoState['GPOLinks'] = @()
                $gpoState['SiteContainers'] = @()
            }

            $__MtSession.ADCache[$cacheKey] = $gpoState

            Write-Verbose "Successfully collected AD GPO State data at $($gpoState.CollectionTime)"
        }
        catch [Management.Automation.CommandNotFoundException] {
            Write-Error "The GroupPolicy or Active Directory module is not installed. Please install RSAT-AD-PowerShell and GPMC or run on a domain-joined machine."
            return $null
        }
        catch {
            Write-Error "Failed to collect AD GPO State data: $($_.Exception.Message)"
            return $null
        }
    }
    else {
        Write-Verbose 'Using cached AD GPO State data'
    }

    return $__MtSession.ADCache[$cacheKey]
}
