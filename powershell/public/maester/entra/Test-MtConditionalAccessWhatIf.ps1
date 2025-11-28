<#
.SYNOPSIS
    Tests Conditional Access evaluation with What If for a given scenario.

.DESCRIPTION
    This function tests a Conditional Access evaluation with What If for a given scenario.

    The function uses the Microsoft Graph API to evaluate the Conditional Access policies.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/what-if-tool
    https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.beta.identity.signins/test-mgbetaidentityconditionalaccess?view=graph-powershell-beta

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId '7a6da1c3-616a-416b-a820-cbe4fa8e225e' `
        -IncludeApplications '00000002-0000-0ff1-ce00-000000000000' `
        -ClientAppType 'exchangeActiveSync'

    This example tests the Conditional Access policies for a user signing into Exchange Online using a legacy Mail client that relies on basic authentication.

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId '7a6da1c3-616a-416b-a820-cbe4fa8e225e' `
        -UserAction 'registerOrJoinDevices'

    This example tests the Conditional Access policies for a user registering or joining a device to Microsoft Entra.

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId '7a6da1c3-616a-416b-a820-cbe4fa8e225e' `
        -IncludeApplications '67ad5377-2d78-4ac2-a867-6300cda00e85' `
        -Country 'FR' -IpAddress '92.205.185.202'

    This example tests the Conditional Access policies for a user signing into **Office 365** from **France** with a specific **IP address**.

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId '7a6da1c3-616a-416b-a820-cbe4fa8e225e' `
        -IncludeApplications '67ad5377-2d78-4ac2-a867-6300cda00e85' `
        -SignInRiskLevel 'High' -DevicePlatform 'iOS'

    This example tests the Conditional Access policies for a user signing into **Office 365** from an **iOS** device with a **High** sign-in risk level.

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId '7a6da1c3-616a-416b-a820-cbe4fa8e225e' `
        -IncludeApplications 'bbad9299-f060-4e15-9a9a-285980ae00fc' `
        -DeviceInfo @{ 'isCompliant' = 'true'; 'Manufacturer' = 'Dell' } `
        -InsiderRiskLevel 'Minor'

    This example tests the Conditional Access policies for a user accessing an **application** from a **compliant**, **Dell** device with a **Minor** insider risk level.

.EXAMPLE
    Test-MtConditionalAccessWhatIf -UserId '7a6da1c3-616a-416b-a820-cbe4fa8e225e' `
        -IncludeApplications 'a7936c39-024c-4148-a9b3-f88f2e9406f6' `
        -ServicePrincipalRiskLevel 'High' -Verbose

    This example tests the Conditional Access policies for a service principal user accessing the **application** with a **High** service principal risk level.
    It will return all applied results, including the report-only and disabled policies.

.LINK
    https://maester.dev/docs/commands/Test-MtConditionalAccessWhatIf
#>
function Test-MtConditionalAccessWhatIf {
    [CmdletBinding(DefaultParameterSetName = 'ApplicationBasedCA')]
    [OutputType([object])]
    param (
        # The id of the user sign-in that is being tested. Must be a valid userId (GUID).
        # UserId can be looked up by `$id = (Get-MgUser -UserId 'john@contoso.com').id`
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory)]
        [ValidateScript({ $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' })]
        [string]$UserId,

        # The id of the application the user is signing into.
        # Must be a valid application ID (GUID)
        # Application ID can be looked up from from the sign in logs.
        # The id of the Office 365 application is '67ad5377-2d78-4ac2-a867-6300cda00e85'
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ApplicationBasedCA', Mandatory)]
        [ValidateScript({ $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' })]
        [string[]]$IncludeApplications,

        # The user action that should be tested.
        # Values can be registerOrJoinDevices or registerSecurityInformation
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'UserActionBasedCA')]
        [ValidateSet('registerOrJoinDevices', 'registerSecurityInformation')]
        [string[]]$UserAction,

        # Device platform to be used for the test.
        # Values can be all, Android, iOS, windows, windowsPhone, macOS, linux
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('all', 'Android', 'iOS', 'windows', 'windowsPhone', 'macOS', 'linux')]
        [string]$DevicePlatform,

        # The client app used by the user.
        # Values can be browser, mobileAppsAndDesktopClients, exchangeActiveSync, easSupported, other
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('browser', 'mobileAppsAndDesktopClients', 'exchangeActiveSync', 'easSupported', 'other')]
        [string]$ClientAppType,

        # Sign-in risk level for the test.
        # Values can be None, Low, Medium, High
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('None', 'Low', 'Medium', 'High')]
        [string]$SignInRiskLevel,

        # User risk level for the test.
        # Values can be None, Low, Medium, High
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('None', 'Low', 'Medium', 'High')]
        [string]$UserRiskLevel,

        # Insider risk level for the test.
        # Values can be Minor, Moderate, Elevated
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Minor', 'Moderate', 'Elevated')]
        [string]$InsiderRiskLevel,

        # Service Principal risk level for the test.
        # Values can be None, Low, Medium, High
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('None', 'Low', 'Medium', 'High')]
        [string]$ServicePrincipalRiskLevel,

        # Device info to be used for the test.
        # Values can be any key-value pair

        #[DeviceInfo <IMicrosoftGraphDeviceInfo>]: deviceInfo
        # 		[(Any) <Object>]: This indicates any property can be added to this object.
        # 		[DeviceId <String>]:
        # 		[DisplayName <String>]:
        # 		[EnrollmentProfileName <String>]:
        # 		[ExtensionAttribute1 <String>]:
        # 		[ExtensionAttribute10 <String>]:
        # 		[ExtensionAttribute11 <String>]:
        # 		[ExtensionAttribute12 <String>]:
        # 		[ExtensionAttribute13 <String>]:
        # 		[ExtensionAttribute14 <String>]:
        # 		[ExtensionAttribute15 <String>]:
        # 		[ExtensionAttribute2 <String>]:
        # 		[ExtensionAttribute3 <String>]:
        # 		[ExtensionAttribute4 <String>]:
        # 		[ExtensionAttribute5 <String>]:
        # 		[ExtensionAttribute6 <String>]:
        # 		[ExtensionAttribute7 <String>]:
        # 		[ExtensionAttribute8 <String>]:
        # 		[ExtensionAttribute9 <String>]:
        # 		[IsCompliant <Boolean?>]:
        # 		[Manufacturer <String>]:
        # 		[MdmAppId <String>]:
        # 		[Model <String>]:
        # 		[OperatingSystem <String>]:
        # 		[OperatingSystemVersion <String>]:
        # 		[Ownership <String>]:
        # 		[PhysicalIds <String []>]:
        # 		[ProfileType <String>]:
        # 		[SystemLabels <String []>]:
        # 		[TrustType <String>]:
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [hashtable]$DeviceInfo,

        # Country to be used for the test. The two-letter country code.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('AD', 'AE', 'AF', 'AG', 'AI', 'AL', 'AM', 'AO', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AW', 'AX', 'AZ', 'BA', 'BB', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI', 'BJ', 'BL', 'BM', 'BN', 'BO', 'BQ', 'BR', 'BS', 'BT', 'BV', 'BW', 'BY', 'BZ', 'CA', 'CC', 'CD', 'CF', 'CG', 'CH', 'CI', 'CK', 'CL', 'CM', 'CN', 'CO', 'CR', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ', 'DE', 'DJ', 'DK', 'DM', 'DO', 'DZ', 'EC', 'EE', 'EG', 'EH', 'ER', 'ES', 'ET', 'FI', 'FJ', 'FK', 'FM', 'FO', 'FR', 'GA', 'GB', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GL', 'GM', 'GN', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GU', 'GW', 'GY', 'HK', 'HM', 'HN', 'HR', 'HT', 'HU', 'ID', 'IE', 'IL', 'IM', 'IN', 'IO', 'IQ', 'IR', 'IS', 'IT', 'JE', 'JM', 'JO', 'JP', 'KE', 'KG', 'KH', 'KI', 'KM', 'KN', 'KP', 'KR', 'KW', 'KY', 'KZ', 'LA', 'LB', 'LC', 'LI', 'LK', 'LR', 'LS', 'LT', 'LU', 'LV', 'LY', 'MA', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MK', 'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MU', 'MV', 'MW', 'MX', 'MY', 'MZ', 'NA', 'NC', 'NE', 'NF', 'NG', 'NI', 'NL', 'NO', 'NP', 'NR', 'NU', 'NZ', 'OM', 'PA', 'PE', 'PF', 'PG', 'PH', 'PK', 'PL', 'PM', 'PN', 'PR', 'PS', 'PT', 'PW', 'PY', 'QA', 'RE', 'RO', 'RS', 'RU', 'RW', 'SA', 'SB', 'SC', 'SD', 'SE', 'SG', 'SH', 'SI', 'SJ', 'SK', 'SL', 'SM', 'SN', 'SO', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ', 'TC', 'TD', 'TF', 'TG', 'TH', 'TJ', 'TK', 'TL', 'TM', 'TN', 'TO', 'TR', 'TT', 'TV', 'TW', 'TZ', 'UA', 'UG', 'UM', 'US', 'UY', 'UZ', 'VA', 'VC', 'VE', 'VG', 'VI', 'VN', 'VU', 'WF', 'WS', 'YE', 'YT', 'ZA', 'ZM', 'ZW')]
        [string]$Country,

        # IP address to be used for the test.
        # e.g. 10.142.84.49
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$IpAddress,

        # Output all results, not only the applied policies.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$AllResults
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'UserActionBasedCA') {
            if ($UserAction.Length -eq 1) {
                $UserActionValue = $UserAction[0] # Array not supported by userAction when there is only one item.
            } else {
                $UserActionValue = $UserAction
            }
            $CAContext = @{
                '@odata.type' = '#microsoft.graph.userActionContext'
                'userAction'  = $UserActionValue
            }
        } else {
            $CAContext = @{
                '@odata.type'         = '#microsoft.graph.applicationContext'
                'includeApplications' = @(
                    $IncludeApplications
                )
            }
        }

        $ConditionalAccessWhatIfBodyParameter = @{
            'AppliedPoliciesOnly' = -not $AllResults
            'signInIdentity'      = @{
                '@odata.type' = '#microsoft.graph.userSignIn'
                'userId'      = $UserId
            }
            'signInContext'       = $CAContext
            'signInConditions'    = @{}
        }

        if ($UserRiskLevel) { $ConditionalAccessWhatIfBodyParameter.signInConditions.userRiskLevel = $UserRiskLevel }
        if ($InsiderRiskLevel) { $ConditionalAccessWhatIfBodyParameter.signInConditions.insiderRiskLevel = $InsiderRiskLevel }
        if ($ServicePrincipalRiskLevel) { $ConditionalAccessWhatIfBodyParameter.signInConditions.servicePrincipalRiskLevel = $ServicePrincipalRiskLevel }
        if ($SignInRiskLevel) { $ConditionalAccessWhatIfBodyParameter.signInConditions.signInRiskLevel = $SignInRiskLevel }
        if ($ClientAppType) { $ConditionalAccessWhatIfBodyParameter.signInConditions.clientAppType = $ClientAppType }
        if ($DevicePlatform) { $ConditionalAccessWhatIfBodyParameter.signInConditions.devicePlatform = $DevicePlatform }
        if ($DeviceInfo) { $ConditionalAccessWhatIfBodyParameter.signInConditions.deviceInfo = $DeviceInfo }
        if ($Country) { $ConditionalAccessWhatIfBodyParameter.signInConditions.country = $Country }
        if ($IpAddress) { $ConditionalAccessWhatIfBodyParameter.signInConditions.ipAddress = $IpAddress }

        Write-Verbose ( $ConditionalAccessWhatIfBodyParameter | ConvertTo-Json -Depth 99 -Compress )

        try {
            $ConditionalAccessWhatIfResult = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/evaluate' -OutputType PSObject -Body ( $ConditionalAccessWhatIfBodyParameter | ConvertTo-Json -Depth 99 -Compress ) | Select-Object -ExpandProperty value
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
