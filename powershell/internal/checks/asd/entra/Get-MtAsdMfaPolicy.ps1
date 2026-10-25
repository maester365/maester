function Get-MtAsdMfaPolicy {
    <#
    .SYNOPSIS
    Returns the enabled Conditional Access policies that require MFA for the given scope, for the ASD checks.

    .DESCRIPTION
    Shared by the Essential Eight multi-factor authentication checks. A policy counts when it is enabled,
    targets all cloud apps, targets the scope (all users, or every privileged directory role) and grants
    access only with multi-factor authentication, or with a phishing-resistant authentication strength when
    -PhishingResistant is given. Policies that only act on Identity Protection risk are left out, because they
    do not require MFA on every sign-in.

    .EXAMPLE
    Get-MtAsdMfaPolicy -Scope AllUsers

    Returns the policies that require MFA for all users on all cloud apps.

    .EXAMPLE
    Get-MtAsdMfaPolicy -Scope PrivilegedRoles -PhishingResistant

    Returns the policies that require a phishing-resistant authentication strength for every privileged role.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Who the policy must cover: every user, or every privileged directory role.
        [Parameter(Mandatory)]
        [ValidateSet('AllUsers', 'PrivilegedRoles')]
        [string] $Scope,

        # Require a phishing-resistant authentication strength instead of any MFA.
        [switch] $PhishingResistant
    )

    # The built-in phishing-resistant strength, and the combinations a custom strength may be limited to.
    $phishingResistantStrengthId = '00000000-0000-0000-0000-000000000004'
    $phishingResistantCombinations = @('windowsHelloForBusiness', 'fido2', 'x509CertificateMultiFactor')

    # The fourteen roles of Microsoft's 'Require MFA for administrators' Conditional Access template, by role
    # template ID; the same set MT.1006 checks.
    $privilegedRoleIds = @(
        '62e90394-69f5-4237-9190-012177145e10', # Global Administrator
        'e8611ab8-c189-46e8-94e1-60213ab1f814', # Privileged Role Administrator
        '7be44c8a-adaf-4e2a-84d6-ab2649e08a13', # Privileged Authentication Administrator
        '194ae4cb-b126-40b2-bd5b-6091b380977d', # Security Administrator
        'fe930be7-5e62-47db-91af-98c3a49a38b1', # User Administrator
        '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3', # Application Administrator
        '158c047a-c907-4556-b7ef-446551a6b5f7', # Cloud Application Administrator
        'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9', # Conditional Access Administrator
        '29232cdf-9323-42fd-ade2-1d097af3e4de', # Exchange Administrator
        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c', # SharePoint Administrator
        'c4e39bd9-1100-46d3-8c65-fb160da0071f', # Authentication Administrator
        '966707d0-3269-4727-9be2-8c3a10f19b9d', # Password Administrator
        'b0f54661-2d74-4c50-afa3-1ec803f12efe', # Billing Administrator
        '729827e3-9c14-49f7-bb1b-9608f156bbb8'  # Helpdesk Administrator
    )

    $policies = @(Get-MtConditionalAccessPolicy | Where-Object {
            $_.state -eq 'enabled' -and
            $_.grantControls.builtInControls -notcontains 'passwordChange' -and
            $_.grantControls.builtInControls -notcontains 'riskRemediation' -and
            -not $_.conditions.userRiskLevels -and
            -not $_.conditions.signInRiskLevels
        })

    foreach ($policy in $policies) {
        if ($policy.conditions.applications.includeApplications -notcontains 'All') { continue }

        $users = $policy.conditions.users
        $coversScope = switch ($Scope) {
            'AllUsers' { $users.includeUsers -contains 'All' }
            'PrivilegedRoles' {
                $users.includeUsers -contains 'All' -or
                @($privilegedRoleIds | Where-Object { $_ -notin $users.includeRoles -or $_ -in $users.excludeRoles }).Count -eq 0
            }
        }
        if (-not $coversScope) { continue }

        # As in MT.1006 and MT.1007, a grant that lists MFA counts even when the operator is OR.
        $grant = $policy.grantControls
        $strength = $grant.authenticationStrength
        $requiresMfa = if ($PhishingResistant) {
            $strength -and (
                $strength.id -eq $phishingResistantStrengthId -or
                ($strength.allowedCombinations -and @($strength.allowedCombinations | Where-Object { $_ -notin $phishingResistantCombinations }).Count -eq 0)
            )
        } else {
            $grant.builtInControls -contains 'mfa' -or $strength.requirementsSatisfied -contains 'mfa'
        }
        if ($requiresMfa) { $policy }
    }
}
