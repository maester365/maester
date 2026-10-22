function Test-ImmutableFederatedCredentialSubject {
    <#
    .SYNOPSIS
    GitHub and GitLab federated identity credentials should use immutable subject identifiers for their subjects.

    .DESCRIPTION
    Examines application federated identity credentials for GitHub Actions and GitLab.
    Reports subjects without the provider-specific immutable identifier markers:
    'repo:<username>@<userid>/<repo>@<repoid>:' for GitHub Actions, with numeric IDs,
    and 'project_id:' for GitLab. Other issuers are not evaluated.
    These marker checks identify potentially mutable subjects, not full subject validity.

    .LINK
    https://maester.dev/docs/commands/Test-ImmutableFederatedCredentialSubject

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
        Control = 'nist-800-53-r5:IA-4',
        Service = 'Graph',
        Lifecycle = 'Preview',
        LongRunning = $true,
        Author = 'nicolonsky'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $findings = [System.Collections.Generic.List[object]]::new()
    $apps = @(Invoke-MtGraphRequest -RelativeUri 'applications?$expand=federatedIdentityCredentials' -Select 'id', 'displayName', 'federatedIdentityCredentials' -ApiVersion beta)
    $appsWithFic = $apps | Where-Object { $null -ne $_.federatedIdentityCredentials -and $_.federatedIdentityCredentials.Count -gt 0 }

    if ($appsWithFic.Count -gt 0) {
        foreach ($app in $appsWithFic) {
            Write-Verbose "Checking federated credentials for application: $($app.displayName) ($($app.id))"
            foreach ($cred in ($app.federatedIdentityCredentials | Where-Object { $null -eq $_.claimsMatchingExpression })) {
                $hasMutableSubject = $false
                switch -Regex ($cred.issuer) {
                    'token.actions.githubusercontent.com' {
                        # Match against immutable identifiers in the subject
                        # e.g.: repository_id:123456, repo:name@123456
                        $hasMutableSubject = $cred.subject -notmatch 'repository_id:\d+' -or $cred.subject -notmatch 'repo:\w+@\d+'
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
    } else {
        Add-MtTestResultDetail -SkippedBecause NotApplicable -Description 'No applications with federated credentials were found.'
        return $null
    }
}
