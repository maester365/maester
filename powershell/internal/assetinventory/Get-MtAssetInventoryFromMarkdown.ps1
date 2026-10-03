function Get-MtAssetInventoryFromMarkdown {
    <#
    .SYNOPSIS
    Extracts asset records from test result markdown by matching known portal deep-link patterns.

    .DESCRIPTION
    Post-hoc parser for existing Maester reports: recovers (System, Type, Id) from the
    finite set of admin-portal deep-link URL patterns used across the shipped checks.
    Works on any markdown string (ResultDetail.TestResult), requires no module session,
    and therefore also handles ad-hoc $portalLink sites that bypass Get-GraphObjectMarkdown.

    When the URL appears inside a markdown link `[name](url)`, the display name is captured too.
    The matched URL is kept as the record's PortalLink.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Markdown content of a test result to scan for entity deep links.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string] $Markdown,

        # Optional test id to stamp on each extracted record for attribution.
        [Parameter(Mandatory = $false)]
        [string] $TestId
    )

    process {
        $guid = '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'

        # Ordered: more specific patterns first. Id = first capture group.
        $patterns = @(
            @{ System   = 'EntraID'; Type = 'ConditionalAccessPolicy'; Regex = "Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/($guid)" }
            @{ System = 'EntraID'; Type = 'ServicePrincipal'; Regex = "ManagedAppMenuBlade/~/\w+/objectId/($guid)/appId/($guid)" }
            @{ System = 'EntraID'; Type = 'AppRegistration'; Regex = "ApplicationMenuBlade/~/\w+/appId/($guid)" }
            @{ System = 'EntraID'; Type = 'User'; Regex = "UserProfileMenuBlade/~/\w+/userId/($guid)" }
            @{ System = 'EntraID'; Type = 'Group'; Regex = "GroupDetailsMenuBlade/~/\w+/groupId/($guid)" }
            @{ System = 'EntraID'; Type = 'Device'; Regex = "DeviceDetailsMenuBlade/~/\w+/objectId/($guid)" }
            @{ System = 'EntraID'; Type = 'AccessPackageCatalog'; Regex = "Microsoft_Azure_ELMAdmin/CatalogBlade/catalogId/($guid)" }
            @{ System = 'EntraID'; Type = 'AccessPackage'; Regex = "EntitlementMenuBlade/~/overview/entitlementId/($guid)" }
            @{ System = 'EntraID'; Type = 'PimAlert'; Regex = "Microsoft_Azure_PIMCommon/AlertDetail/providerId/aadroles/alertId/([^/)\s]+)" }
            @{ System = 'EntraID'; Type = 'EntraRecommendation'; Regex = "RecommendationDetails\.ReactView/recommendationId/([^/)\s]+)" }
            @{ System = 'DefenderXDR'; Type = 'Device'; Regex = "security\.microsoft\.com/machines/v2/([^/?)\s]+)" }
            @{ System = 'ExchangeOnline'; Type = 'TransportRule'; Regex = "transportrules/:/ruleDetails/($guid)" }
            @{ System = 'ExchangeOnline'; Type = 'SharingPolicy'; Regex = "individualsharing/:/individualsharingdetails/([^/)\s]+)" }
        )

        $records = [System.Collections.Generic.List[object]]::new()
        if ([string]::IsNullOrWhiteSpace($Markdown)) { return @() }

        # Enumerate the links once and test each url against the table, rather than scanning the
        # whole markdown per pattern: the url is then available as the PortalLink, and the display
        # name comes from the link that owns it instead of a second search that can pick a
        # different occurrence. .NET allows the repeated 'url' group name across the alternation.
        # https only: display names are not escaped in result markdown, so a crafted name can smuggle
        # a javascript: url into a link that would otherwise match a portal pattern.
        $linkPattern = '\[(?<name>[^\]]+)\]\((?<url>https://[^)\s]+)\)|(?<url>https://[^\s)\]]+)'

        foreach ($link in [regex]::Matches($Markdown, $linkPattern)) {
            $url = $link.Groups['url'].Value
            if ([string]::IsNullOrEmpty($url)) { continue }

            foreach ($pattern in $patterns) {
                $match = [regex]::Match($url, $pattern.Regex)
                if (-not $match.Success) { continue }

                $records.Add([PSCustomObject]@{
                        System      = $pattern.System
                        AnchorKind  = 'Instance'
                        Type        = $pattern.Type
                        Id          = $match.Groups[1].Value
                        DisplayName = if ($link.Groups['name'].Success) { $link.Groups['name'].Value } else { $null }
                        PortalLink  = $url
                        TestId      = $TestId
                        Source      = 'Markdown'
                    })
                # Patterns are ordered most specific first, so the first hit owns the url.
                break
            }
        }

        # Dedupe within this markdown blob: a check commonly links the same object from several rows.
        $deduped = $records | Group-Object -Property { "$($_.System)|$($_.Type)|$($_.Id)" } | ForEach-Object { $_.Group[0] }
        return @($deduped)
    }
}
