function Test-MtConditionalAccessWhatIf {
    [CmdletBinding(DefaultParameterSetName = 'ApplicationBasedCA')]
    [OutputType([object])]
    param (
        # The UserId to test the Conditional Acccess policie with
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory)]
        [string]$UserId,

        # The applications that should be tested Default: All
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "ApplicationBasedCA")]
        [string[]]$IncludeApplications = "All",

        # The user action that should be tested. Default: registerOrJoinDevices
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "UserActionBasedCA")]
        [ValidateSet("registerOrJoinDevices", "registerSecurityInformation")]
        [string[]]$UserAction = "registerOrJoinDevices",

        # The device platform that should be tested. Default: windows
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Android", "iOS", "windows", "windowsPhone", "macOS", "linux")]
        [string]$DevicePlatform = "windows",

        # The client app used by the user. Default: all
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("all", "browser", "mobileAppsAndDesktopClients", "exchangeActiveSync", "easSupported", "other")]
        [string]$ClientAppType = "all",

        # The sign in risk level of the user sign-in. Default: None
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("None", "Low", "Medium", "High")]
        [string]$SignInRiskLevel = "None",

        # The user risk level of the user signing in. Default: None
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("None", "Low", "Medium", "High")]
        $UserRiskLevel = "None"
    )

    process {
        # Definition of conditional access
        if ($PSCmdlet.ParameterSetName -eq "UserActionBasedCA") {
            $CAContext = @{
                "@odata.type" = "#microsoft.graph.whatIfUserActionContext"
                "userAction"  = $UserAction
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
                "userId"      = "$userId"
            }
            "conditionalAccessContext"          = $CAContext
            "conditionalAccessWhatIfConditions" = @{
                "signInRiskLevel" = $SignInRiskLevel
                "clientAppType"   = $ClientAppType
                "devicePlatform"  = $DevicePlatform
            }
        }

        Write-Verbose ( $ConditionalAccessWhatIfDefinition | ConvertTo-Json -Depth 99 -Compress )

        try {
            $ConditionalAccessWhatIfResult = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/evaluate" -Body ( $ConditionalAccessWhatIfDefinition | ConvertTo-Json -Depth 99 -Compress ) | Select-Object -ExpandProperty value
            # Output raw result for debugging
            Write-Verbose ( $ConditionalAccessWhatIfResult | ConvertTo-Json -Depth 99 | Out-String )
            # Filter out policies that do not apply
            $ConditionalAccessWhatIfResult = $ConditionalAccessWhatIfResult | Where-Object { $_.policyApplies -eq $true }
            # Output filtered results
            return $ConditionalAccessWhatIfResult
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}