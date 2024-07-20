<#
.SYNOPSIS
  Returns DisplayName and IsMfa metadata about a specific user authentication method type

.DESCRIPTION
    The user authentication method returned by the /users/{id}/authentication/methods endpoint
    is missing key information such as the display name (as shown in the Portal) and if an auth method
    is a multi-factor authentication method or not.

    This cmdlet returns the DisplayName and IsMfa metadata for a specific user authentication method type.

.EXAMPLE

    $userId = 'john@contoso.com'
    $userAuthMethods = Invoke-MtGraphRequest -RelativeUri "users/$userId/authentication/methods"
    $authMethod | Get-MtUserAuthenticationMethodInfoByType

    # Returns the DisplayName and IsMfa metadata for the authentication methods registered by the specified user.

.LINK
    https://maester.dev/docs/commands/Get-MtUserAuthenticationMethodInfoByType
#>
function Get-MtUserAuthenticationMethodInfoByType {

    [CmdletBinding()]
    param(
        # The type of authentication method to get metadata for
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [psobject] $AuthenticationMethod
    )

    begin {
        # Static list of each auth method and its metadata
        # This is used to determine if the auth method is MFA or not
        # Update this list as new methods are added by Microsoft
        # ReportType maps to the type returned when the /reports/authenticationMethods/userRegistrationDetails endpoint is used
        # Type maps to the type returned when the /users/{id}/authentication/methods endpoint is used
        $authMethodMetadata = @(
            @{
                ReportType  = 'passKeyDeviceBoundAuthenticator'
                Type        = $null
                DisplayName = 'Passkey (Microsoft Authenticator)'
                IsMfa       = $true
            },
            @{
                ReportType  = 'passKeyDeviceBound'
                Type        = '#microsoft.graph.fido2AuthenticationMethod'
                DisplayName = "Passkey (other device-bound)"
                IsMfa       = $true
            },
            @{
                ReportType  = 'email'
                Type        = '#microsoft.graph.emailAuthenticationMethod'
                DisplayName = 'Email'
                IsMfa       = $false
            },
            @{
                ReportType  = 'microsoftAuthenticatorPush'
                Type        = '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'
                DisplayName = 'Microsoft Authenticator'
                IsMfa       = $true
            },
            @{
                ReportType  = 'mobilePhone'
                Type        = '#microsoft.graph.phoneAuthenticationMethod'
                DisplayName = 'Phone'
                IsMfa       = $true
            },
            @{
                ReportType  = 'softwareOneTimePasscode'
                Type        = '#microsoft.graph.softwareOathAuthenticationMethod'
                DisplayName = 'Authenticator app (TOTP)'
                IsMfa       = $true
            },
            @{
                ReportType  = $null
                Type        = '#microsoft.graph.temporaryAccessPassAuthenticationMethod'
                DisplayName = 'Temporary Access Pass'
                IsMfa       = $false
            },
            @{
                ReportType  = 'windowsHelloForBusiness'
                Type        = '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod'
                DisplayName = 'Windows Hello for Business'
                IsMfa       = $true
            },
            @{
                ReportType  = $null
                Type        = '#microsoft.graph.passwordAuthenticationMethod'
                DisplayName = 'Password'
                IsMfa       = $false
            },
            @{
                ReportType  = $null
                Type        = '#microsoft.graph.platformCredentialAuthenticationMethod'
                DisplayName = 'Platform Credential for MacOS'
                IsMfa       = $true
            },
            @{
                ReportType  = 'microsoftAuthenticatorPasswordless'
                Type        = '#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod'
                DisplayName = 'Microsoft Authenticator'
                IsMfa       = $true
            }
        )
    }
    process {
        function GetMethodInfo($authMethod) {
            $type = $authMethod.'@odata.type'
            $methodInfo = $authMethodMetadata | Where-Object { $_.Type -eq $type }
            if ($null -eq $methodInfo) {
                # Default to the type and assume it is MFA
                $methodInfo = @{
                    Type        = $type
                    DisplayName = ($type -replace '#microsoft.graph.', '') -replace 'AuthenticationMethod', ''
                    IsMfa       = $true
                }
            }
            Write-Output $methodInfo
        }

        if ($AuthenticationMethod -is [array]) {
            Write-Verbose "Processing multiple authentication methods"
            $AuthenticationMethod | ForEach-Object { GetMethodInfo $_ }
        } else {
            Write-Verbose "Processing single authentication method"
            GetMethodInfo $AuthenticationMethod
        }
    }
}