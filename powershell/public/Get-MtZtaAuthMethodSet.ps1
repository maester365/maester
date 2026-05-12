function Get-MtZtaAuthMethodSet {
    <#
    .SYNOPSIS
        Returns curated classification of Microsoft Graph `methodsRegistered` enum values
        into PhishResistant / Phishable / SingleFactor / All buckets.

    .DESCRIPTION
        Centralises the classification used by ZTA-aware MFA-uplift tests
        (MT.Zta.1140 / 1141 / 1142 / 1143) so a single source of truth feeds every
        check. Without this helper, each test inlines a different ad-hoc regex /
        array which drifts as Microsoft adds new methods.

        Classification rationale:

        - **PhishResistant** — methods whose protocol prevents an attacker-controlled
          relay site from harvesting the credential (FIDO2/WebAuthn binding the
          credential to the relying-party origin, X.509 cert with PIN, Windows Hello
          for Business, device-bound passkeys).

        - **Phishable** — every interactive method that an AiTM proxy or social-eng
          attack can capture or replay: phone-bound (`mobilePhone` /
          `alternateMobilePhone` / `officePhone` — these are the URD enum values
          for what user-facing tooling calls "SMS"; URD does NOT emit `sms`),
          `voice`, email OTP, software & hardware TOTP, Authenticator push (consent
          fatigue), and — controversially — `microsoftAuthenticatorPasswordless`.
          Microsoft markets the latter as MFA, but it functionally collapses to
          "approve push on the same device that owns the session", so under a
          stolen-device threat model it behaves as single-factor and is included here.

          Note: `sms` is a value in the CA `authenticationMethodModes` enum (used
          by authStrength `allowedCombinations`), NOT the URD `methodsRegistered`
          enum this cmdlet models. The CA-side vocabulary is checked inline in
          MT.Zta.1131; this cmdlet feeds the user-data-side checks
          (MT.Zta.1140 / 1141 / 1142 / 1143) that read URD rows.

          `temporaryAccessPass` is included while active (it's an inline-issued
          password substitute used for bootstrapping; phishable like any password).

          `federatedSingleFactor` is included because the trust delegates auth to an
          external IdP with no MFA assertion — phishable at the IdP boundary.

        - **SingleFactor** — methods that are explicitly NOT MFA at all
          (`x509CertificateSingleFactor` is cert without PIN; `password` is a
          password). Listed for completeness; absent tenants typically don't have
          these as `methodsRegistered` rows.

        References:

        - Graph schema: https://learn.microsoft.com/graph/api/resources/userregistrationdetails
        - Microsoft phish-resistant MFA list: https://learn.microsoft.com/azure/active-directory/authentication/concept-authentication-strengths

    .PARAMETER Bucket
        Which classification bucket to return. Default returns the full hashtable.

    .EXAMPLE
        $classes = Get-MtZtaAuthMethodSet
        $hasOnlyWeak = -not (@($u.methodsRegistered | Where-Object { $_ -in $classes.PhishResistant }).Count -gt 0)

    .EXAMPLE
        $phishable = Get-MtZtaAuthMethodSet -Bucket Phishable
        if (@($u.methodsRegistered | Where-Object { $_ -in $phishable }).Count -gt 0) { ... }

    .LINK
        https://maester.dev/docs/commands/Get-MtZtaAuthMethodSet

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding()]
    [OutputType([hashtable], [string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('PhishResistant', 'Phishable', 'SingleFactor', 'All')]
        [string] $Bucket = 'All'
    )

    $classes = @{
        PhishResistant = @(
            'fido2',
            'windowsHelloForBusiness',
            'x509CertificateMultiFactor',
            'passKey',
            'passKeyDeviceBound',
            'passKeyDeviceBoundAuthenticator',
            'passKeyDeviceBoundWindowsHello',
            'passKeyDeviceBoundExternalAuthenticator',
            'federatedMultiFactor'
        )
        Phishable = @(
            'mobilePhone',
            'alternateMobilePhone',
            'officePhone',
            'voice',
            'email',
            'softwareOneTimePasscode',
            'hardwareOneTimePasscode',
            'microsoftAuthenticatorPush',
            'microsoftAuthenticatorOath',
            'microsoftAuthenticatorPasswordless',
            'temporaryAccessPass',
            'federatedSingleFactor'
        )
        SingleFactor = @(
            'x509CertificateSingleFactor',
            'password'
        )
    }

    if ($Bucket -eq 'All') { return $classes }
    return $classes[$Bucket]
}
