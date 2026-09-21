Describe 'Test-MtCaSecureSecurityInfoRegistration' {
  BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    Mock -ModuleName Maester Get-MtLicenseInformation { return "P1" }

    # Otherwise valid "secure security info registration from a trusted location"
    # policy, but scoped to the browser client app only. Registration is also
    # triggered from native apps such as Microsoft Authenticator, so this leaves a
    # gap and must fail. Reported as a false positive in #2105; the check is
    # working as intended and the test result now explains why.
    function Get-SecureRegistrationPolicyBrowserClientApp {
      $policyJson = @"
[
  {
    "state": "enabled",
    "conditions": {
      "clientAppTypes": [
        "browser"
      ],
      "applications": {
        "includeUserActions": [
          "urn:user:registersecurityinfo"
        ]
      },
      "users": {
        "includeUsers": [
          "All"
        ]
      },
      "locations": {
        "includeLocations": [
          "All"
        ],
        "excludeLocations": [
          "AllTrusted"
        ]
      }
    },
    "grantControls": {
      "operator": "OR",
      "builtInControls": [
        "mfa"
      ]
    }
  }
]
"@
      return $policyJson | ConvertFrom-Json
    }

    # Same valid policy but scoped to all client apps.
    function Get-SecureRegistrationPolicyAllClientApp {
      $policyJson = @"
[
  {
    "state": "enabled",
    "conditions": {
      "clientAppTypes": [
        "all"
      ],
      "applications": {
        "includeUserActions": [
          "urn:user:registersecurityinfo"
        ]
      },
      "users": {
        "includeUsers": [
          "All"
        ]
      },
      "locations": {
        "includeLocations": [
          "All"
        ],
        "excludeLocations": [
          "AllTrusted"
        ]
      }
    },
    "grantControls": {
      "operator": "OR",
      "builtInControls": [
        "mfa"
      ]
    }
  }
]
"@
      return $policyJson | ConvertFrom-Json
    }

    # Registration policy that does not exclude any (trusted) location - this is
    # not "from a trusted location only" and must fail.
    function Get-SecureRegistrationPolicyNoExcludedLocation {
      $policyJson = @"
[
  {
    "state": "enabled",
    "conditions": {
      "clientAppTypes": [
        "all"
      ],
      "applications": {
        "includeUserActions": [
          "urn:user:registersecurityinfo"
        ]
      },
      "users": {
        "includeUsers": [
          "All"
        ]
      },
      "locations": {
        "includeLocations": [
          "All"
        ],
        "excludeLocations": null
      }
    },
    "grantControls": {
      "operator": "OR",
      "builtInControls": [
        "mfa"
      ]
    }
  }
]
"@
      return $policyJson | ConvertFrom-Json
    }

    # Policy scoped only to mobile apps and desktop clients. Like the browser-only
    # policy above, this covers some registration paths but not all, so it must fail.
    function Get-SecureRegistrationPolicyMobileClientAppOnly {
      $policyJson = @"
[
  {
    "state": "enabled",
    "conditions": {
      "clientAppTypes": [
        "mobileAppsAndDesktopClients"
      ],
      "applications": {
        "includeUserActions": [
          "urn:user:registersecurityinfo"
        ]
      },
      "users": {
        "includeUsers": [
          "All"
        ]
      },
      "locations": {
        "includeLocations": [
          "All"
        ],
        "excludeLocations": [
          "AllTrusted"
        ]
      }
    },
    "grantControls": {
      "operator": "OR",
      "builtInControls": [
        "mfa"
      ]
    }
  }
]
"@
      return $policyJson | ConvertFrom-Json
    }

    # Correctly scoped policy but targeting a resource instead of the
    # registersecurityinfo user action - must fail.
    function Get-SecureRegistrationPolicyWrongTarget {
      $policyJson = @"
[
  {
    "state": "enabled",
    "conditions": {
      "clientAppTypes": [
        "all"
      ],
      "applications": {
        "includeApplications": [
          "All"
        ]
      },
      "users": {
        "includeUsers": [
          "All"
        ]
      },
      "locations": {
        "includeLocations": [
          "All"
        ],
        "excludeLocations": [
          "AllTrusted"
        ]
      }
    },
    "grantControls": {
      "operator": "OR",
      "builtInControls": [
        "mfa"
      ]
    }
  }
]
"@
      return $policyJson | ConvertFrom-Json
    }

    # Otherwise valid policy that excludes a single named location by ID. Whether it
    # secures registration depends entirely on whether that location is trusted, which
    # the caller decides by mocking Get-MtTrustedNamedLocationId.
    function Get-SecureRegistrationPolicyExcludingNamedLocation {
      param([string] $LocationId)
      $policyJson = @"
[
  {
    "state": "enabled",
    "conditions": {
      "clientAppTypes": [
        "all"
      ],
      "applications": {
        "includeUserActions": [
          "urn:user:registersecurityinfo"
        ]
      },
      "users": {
        "includeUsers": [
          "All"
        ]
      },
      "locations": {
        "includeLocations": [
          "All"
        ],
        "excludeLocations": [
          "$LocationId"
        ]
      }
    },
    "grantControls": {
      "operator": "OR",
      "builtInControls": [
        "mfa"
      ]
    }
  }
]
"@
      return $policyJson | ConvertFrom-Json
    }
  }

  Context "CA: Secure security info registration" {

    It 'Policy scoped to the browser client app only should fail (#2105)' {
      $policy = Get-SecureRegistrationPolicyBrowserClientApp
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
    }

    It 'Policy scoped to all client apps should pass' {
      $policy = Get-SecureRegistrationPolicyAllClientApp
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeTrue
    }

    It 'Policy that does not exclude any location should fail without resolving named locations' {
      $policy = Get-SecureRegistrationPolicyNoExcludedLocation
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
      Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return @() }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
      Should -Invoke Get-MtTrustedNamedLocationId -ModuleName Maester -Times 0 -Exactly
    }

    It 'Policy scoped only to mobile apps and desktop clients should fail' {
      $policy = Get-SecureRegistrationPolicyMobileClientAppOnly
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
    }

    It 'Policy not targeting the registersecurityinfo user action should fail' {
      $policy = Get-SecureRegistrationPolicyWrongTarget
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
    }

  }

  Context "CA: Excluded location must be trusted" {

    BeforeAll {
      $script:trustedId = '11111111-1111-1111-1111-111111111111'
      $script:untrustedId = '22222222-2222-2222-2222-222222222222'
    }

    It 'Policy excluding a trusted named location should pass' {
      $policy = Get-SecureRegistrationPolicyExcludingNamedLocation -LocationId $script:trustedId
      $trusted = @($script:trustedId)
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
      Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return $trusted }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeTrue
    }

    It 'Policy excluding an untrusted named location should fail (#2227)' {
      $policy = Get-SecureRegistrationPolicyExcludingNamedLocation -LocationId $script:untrustedId
      $trusted = @($script:trustedId)
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
      Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return $trusted }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
    }

    It 'Policy excluding a location that no longer exists should fail' {
      $policy = Get-SecureRegistrationPolicyExcludingNamedLocation -LocationId '33333333-3333-3333-3333-333333333333'
      $trusted = @($script:trustedId)
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
      Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return $trusted }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
    }

    It 'Policy excluding a named location should fail when the tenant has no trusted location' {
      $policy = Get-SecureRegistrationPolicyExcludingNamedLocation -LocationId $script:untrustedId
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
      Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return @() }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
    }

    It 'Policy excluding AllTrusted should pass without resolving named locations' {
      $policy = Get-SecureRegistrationPolicyAllClientApp
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
      Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return @() }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeTrue
      Should -Invoke Get-MtTrustedNamedLocationId -ModuleName Maester -Times 0 -Exactly
    }

  }

  Context "Get-MtTrustedNamedLocationId" {

    It 'Returns only trusted IP named locations' {
      Mock -ModuleName Maester Invoke-MtGraphRequest {
        return @"
[
  { "id": "trusted-ip",   "@odata.type": "#microsoft.graph.ipNamedLocation",      "isTrusted": true  },
  { "id": "untrusted-ip", "@odata.type": "#microsoft.graph.ipNamedLocation",      "isTrusted": false },
  { "id": "country",      "@odata.type": "#microsoft.graph.countryNamedLocation"                     }
]
"@ | ConvertFrom-Json
      }

      $result = InModuleScope Maester { Get-MtTrustedNamedLocationId }

      $result | Should -Be @('trusted-ip')
    }

    It 'Returns an empty array when the tenant has no named locations' {
      Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

      $result = InModuleScope Maester { Get-MtTrustedNamedLocationId }

      @($result).Count | Should -Be 0
    }

  }
}
