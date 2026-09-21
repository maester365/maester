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

    It 'Policy that does not exclude a trusted location should fail' {
      $policy = Get-SecureRegistrationPolicyNoExcludedLocation
      Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }

      Test-MtCaSecureSecurityInfoRegistration | Should -BeFalse
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
}
