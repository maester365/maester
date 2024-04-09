<#
.SYNOPSIS
    Test Conditional Access What If scenario.

.DESCRIPTION
    This function tests a Conditional Access evaluation with What If for a given scenario.

    The function uses the Microsoft Graph API to evaluate the Conditional Access policies.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/what-if-tool

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId 7a6da1c3-616a-416b-a820-cbe4fa8e225e -IncludeApplications "00000002-0000-0ff1-ce00-000000000000" -ClientAppType exchangeActiveSync

    This example tests the Conditional Access policies for a user signing into Exchange Online using a legacy Mail client that relies on basic authentication.

    Test-MtConditionalAccessWhatIf -UserId 7a6da1c3-616a-416b-a820-cbe4fa8e225e -UserAction registerOrJoinDevices

    This example tests the Conditional Access policies for a user signing into Exchange Online using a legacy Mail client that relies on basic authentication.

#>
function Test-MtConditionalAccessWhatIf {
    [CmdletBinding(DefaultParameterSetName = 'ApplicationBasedCA')]
    [OutputType([object])]
    param (
        # The UserId to test the Conditional Acccess policie with
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory)]
        [ValidateScript({ $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' })]
        [string]$UserId,

        # The applications that should be tested
        # Must be a valid application ID (GUID)
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "ApplicationBasedCA", Mandatory)]
        [ValidateScript({ $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' })]
        [string[]]$IncludeApplications,

        # The user action that should be tested.
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "UserActionBasedCA")]
        [ValidateSet("registerOrJoinDevices", "registerSecurityInformation")]
        [string[]]$UserAction,

        # The device platform that should be tested.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("all", "Android", "iOS", "windows", "windowsPhone", "macOS", "linux")]
        [string]$DevicePlatform,

        # The client app used by the user.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("browser", "mobileAppsAndDesktopClients", "exchangeActiveSync", "easSupported", "other")]
        [string]$ClientAppType,

        # The sign in risk level of the user sign-in.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("None", "Low", "Medium", "High")]
        [string]$SignInRiskLevel,

        # The user risk level of the user signing in.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("None", "Low", "Medium", "High")]
        [string]$UserRiskLevel,

        # The country of the user signing in.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ", "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW")]
        [string]$Country,

        # The ipAddress of the user signing in.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$IpAddress,

        # Output all results
        [Parameter()]
        [switch]$AllResults
    )

    process {
        # Definition of conditional access
        if ($PSCmdlet.ParameterSetName -eq "UserActionBasedCA") {
            if ($UserAction.Length -eq 1) {
                $UserActionValue = $UserAction[0] # Array not supported by userAction when there is only one item.
            } else {
                $UserActionValue = $UserAction
            }
            $CAContext = @{
                "@odata.type" = "#microsoft.graph.whatIfUserActionContext"
                "userAction"  = $UserActionValue
            }
        } else {
            $CAContext = @{
                "@odata.type"         = "#microsoft.graph.whatIfApplicationContext"
                "includeApplications" = @(
                    $IncludeApplications
                )
            }
        }

        $ConditionalAccessWhatIfDefinition = @{
            "conditionalAccessWhatIfSubject"    = @{
                "@odata.type" = "#microsoft.graph.userSubject"
                "userId"      = $UserId
            }
            "conditionalAccessContext"          = $CAContext
            "conditionalAccessWhatIfConditions" = @{}
        }

        $whatIfConditions = $ConditionalAccessWhatIfDefinition.conditionalAccessWhatIfConditions

        if ($UserRiskLevel) { $whatIfConditions.userRiskLevel = $UserRiskLevel }
        if ($SignInRiskLevel) { $whatIfConditions.signInRiskLevel = $SignInRiskLevel }
        if ($ClientAppType) { $whatIfConditions.clientAppType = $ClientAppType }
        if ($DevicePlatform) { $whatIfConditions.devicePlatform = $DevicePlatform }
        if ($Country) { $whatIfConditions.country = $Country }
        if ($IpAddress) { $whatIfConditions.ipAddress = $IpAddress }

        Write-Verbose ( $ConditionalAccessWhatIfDefinition | ConvertTo-Json -Depth 99 -Compress )

        try {
            $ConditionalAccessWhatIfResult = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/evaluate" -OutputType PSObject -Body ( $ConditionalAccessWhatIfDefinition | ConvertTo-Json -Depth 99 -Compress ) | Select-Object -ExpandProperty value
            # Filter out policies that do not apply
            if (!$AllResults) {
                $ConditionalAccessWhatIfResult = $ConditionalAccessWhatIfResult | Where-Object { $_.policyApplies -eq $true }
            }
            return $ConditionalAccessWhatIfResult
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}

