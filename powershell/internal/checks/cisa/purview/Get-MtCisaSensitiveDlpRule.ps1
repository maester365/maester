function Get-MtCisaSensitiveDlpRule {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $policies = @(Get-MtExo -Request DlpCompliancePolicy)
    $rules = @(Get-MtExo -Request DlpComplianceRule)
    $sensitiveTypeIds = @(
        '50842eb7-edc8-4019-85dd-5a5c1f2bb085',
        'a44669fe-0d48-453d-a9b1-2cc83f2cba77',
        'e55e2a32-f92d-4985-a35d-a0b269eb687b'
    )
    $sensitiveTypes = @(
        [pscustomobject]@{ Name = 'Credit Card Number'; Id = $sensitiveTypeIds[0] }
        [pscustomobject]@{ Name = 'U.S. Social Security Number (SSN)'; Id = $sensitiveTypeIds[1] }
        [pscustomobject]@{ Name = 'U.S. Individual Taxpayer Identification Number (ITIN)'; Id = $sensitiveTypeIds[2] }
    )

    $enabledPolicies = @(
        $policies | Where-Object { $_.Enabled -eq $true -and $_.Mode -eq 'Enable' } |
            ForEach-Object {
                [pscustomobject]@{
                    Name   = $_.Name
                    Policy = $_
                }
            }
    )

    $fullProtectionRules = foreach ($rule in $rules) {
        if ($rule.Disabled -ne $false) {
            continue
        }

        $parentPolicy = $enabledPolicies |
            Where-Object { $_.Name -eq $rule.ParentPolicyName -or $_.Policy.Identity -eq $rule.ParentPolicyName } |
            Select-Object -First 1
        if (-not $parentPolicy) {
            continue
        }

        $matchedTypes = [System.Collections.Generic.List[string]]::new()
        if ($rule.IsAdvancedRule -ne $true) {
            foreach ($contentType in @($rule.ContentContainsSensitiveInformation)) {
                $contentName = if ($contentType -is [string]) {
                    $contentType
                } elseif ($contentType.Name) {
                    [string]$contentType.Name
                } else {
                    [string]$contentType.DisplayName
                }

                foreach ($sensitiveType in $sensitiveTypes) {
                    if ($contentName -ieq $sensitiveType.Name -and $sensitiveType.Name -notin $matchedTypes) {
                        $matchedTypes.Add($sensitiveType.Name)
                    }
                }
            }
        }

        if ($rule.IsAdvancedRule -ne $false) {
            $advancedRule = [string]$rule.AdvancedRule
            foreach ($sensitiveType in $sensitiveTypes) {
                if (
                    ($advancedRule -match [regex]::Escape($sensitiveType.Name) -or
                        $advancedRule -match [regex]::Escape($sensitiveType.Id)) -and
                    $sensitiveType.Name -notin $matchedTypes
                ) {
                    $matchedTypes.Add($sensitiveType.Name)
                }
            }
        }

        if ($matchedTypes.Count -eq $sensitiveTypes.Count) {
            [pscustomobject]@{
                Policy = $parentPolicy.Policy
                Rule   = $rule
            }
        }
    }

    return @($fullProtectionRules)
}
