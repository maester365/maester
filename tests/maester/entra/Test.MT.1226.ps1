function Test-MT1226 {
    <#
    .SYNOPSIS
    GitHub and GitLab federated identity credentials should use immutable subject identifiers.

    .DESCRIPTION
    Examines application federated identity credentials for GitHub Actions and GitLab.
    Reports subjects without the provider-specific immutable identifier markers:
    '@' for GitHub Actions and 'project_id:' for GitLab. Other issuers are not evaluated.
    These marker checks identify potentially mutable subjects, not full subject validity.

    .LINK
    https://learn.microsoft.com/en-us/entra/workload-id/workload-identities-github-immutable-subjects

    .LINK
    https://learn.microsoft.com/en-us/entra/workload-id/workload-identities-federated-credential-mutable-subjects
    #>
    [MaesterTest(
        Id = 'MT.1226',
        Title = 'GitHub and GitLab federated identity credentials should use immutable subject identifiers.',
        Product = 'entra',
        RelatedProduct = 'github',
        Feature = 'applications',
        Area = 'authentication',
        ResourceType = 'Application',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1199',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Lifecycle = 'Preview',
        LongRunning = $true,
        Author = 'nicolonsky'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $findings = [System.Collections.Generic.List[object]]::new()
    $apps = @(Invoke-MtGraphRequest -RelativeUri 'applications' -Select 'id', 'displayName' -ApiVersion beta -ErrorAction Stop)

    foreach ($app in $apps) {
        Write-Verbose "Checking federated credentials for application: $($app.displayName) ($($app.id))"
        $federatedCredentials = @(Invoke-MtGraphRequest -RelativeUri "applications/$($app.id)/federatedIdentityCredentials" -ApiVersion beta -ErrorAction Stop)

        foreach ($cred in $federatedCredentials) {
            $hasMutableSubject = $false
            switch -Regex ($cred.issuer) {
                'token.actions.githubusercontent.com' {
                    Write-Verbose "Found federated credential with GitHub Actions issuer: $($cred.name)"
                    $hasMutableSubject = $cred.subject -notmatch '@'
                    break
                }
                'gitlab' {
                    Write-Verbose "Found federated credential with GitLab issuer: $($cred.name)"
                    $hasMutableSubject = $cred.subject -notmatch 'project_id:'
                    break
                }
                default {
                    Write-Verbose "Skipping unsupported issuer: $($cred.issuer)"
                    break
                }
            }

            if ($hasMutableSubject) {
                $finding = [pscustomobject]@{
                    Application   = $app.displayName
                    ApplicationId = $app.id
                    Credential    = $cred.name
                    Issuer        = $cred.issuer
                    Subject       = $cred.subject
                }
                $findings.Add($finding)
            }
        }
    }

    $passed = $findings.Count -eq 0
    $resultMarkdown = "Scanned $($apps.Count) applications. "
    if ($passed) {
        $resultMarkdown += 'No GitHub or GitLab federated identity credentials were found with subjects missing the checked immutable identifier markers.'
    } else {
        $resultMarkdown += "Found $($findings.Count) GitHub or GitLab federated identity credentials with subjects missing immutable identifier markers."
        $rows = foreach ($finding in $findings) {
            $cells = @($finding.Application, $finding.ApplicationId, $finding.Credential, $finding.Issuer, $finding.Subject) | ForEach-Object {
                [System.Net.WebUtility]::HtmlEncode([string]$_).Replace('|', '\|') -replace '[\r\n]+', ' '
            }
            '| {0} | {1} | {2} | {3} | {4} |' -f $cells
        }
        $resultMarkdown += "`n`n| Application | Application object ID | Credential | Issuer | Subject |`n| --- | --- | --- | --- | --- |`n"
        $resultMarkdown += $rows -join "`n"
    }

    $null = Add-MtTestResultDetail -Result $resultMarkdown
    return $passed
}
