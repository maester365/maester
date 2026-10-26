function Test-MtImmutableFederatedCredentialSubject {
    <#
    .SYNOPSIS
    GitHub and GitLab federated identity credentials should use immutable subject identifiers for their subjects.

    .DESCRIPTION
    Examines application federated identity credentials for GitHub Actions and GitLab.
    Evaluates each credential's subject rule, or its claimsMatchingExpression value when configured.
    Identifies GitLab OIDC credentials by common GitLab claims, including 'project_id',
    'project_path' and 'ref_type'. Reports rules without the provider-specific immutable
    identifier markers:
    'repo:<username>@<userid>/<repo>@<repoid>:' for GitHub Actions, with numeric IDs,
    and 'project_id:' for GitLab. GitHub credentials are identified by issuer; GitLab
    credentials are identified by their claims.
    These marker checks identify potentially mutable subjects, not full subject validity.

    .LINK
    https://maester.dev/docs/commands/Test-MtImmutableFederatedCredentialSubject

    #>
    [MaesterTest(
        Id = 'MT.1226',
        Title = 'GitHub and GitLab federated identity credentials should use immutable subject identifiers.',
        Product = 'entra',
        RelatedProduct = 'github',
        Feature = 'applications',
        Area = 'applications',
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



    # Identify OIDC tokens from GitLab either via project_id, project_path or ref_type claims
    $gitLabOidcIdentifiers = '(?:^|[''"])project_(?:id|path):|(?:^|[:''"])ref_type:'
    # GitLab immutable OIDC claims pattern
    $gitLabImmutableOidcClaims = 'project_id'
    # Matches GitHub Actions immutable OIDC claims
    $gitHubImmutableOidcClaims = 'repo:.+@\d+\/.+@\d+:|repository_id'

    try {
        $apps = @(Invoke-MtGraphRequest -RelativeUri 'applications?$expand=federatedIdentityCredentials' -Select 'id', 'displayName', 'federatedIdentityCredentials' -ApiVersion beta -ErrorAction Stop)
    } catch [System.UnauthorizedAccessException] {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
    }

    $appsWithFic = $apps | Where-Object { $null -ne $_.federatedIdentityCredentials -and $_.federatedIdentityCredentials.Count -gt 0 }
    $findings = [System.Collections.Generic.List[object]]::new()

    if ($appsWithFic.Count -gt 0) {
        $applicableCount = 0
        foreach ($app in $appsWithFic) {
            Write-Verbose "Checking federated credentials for application: $($app.displayName) ($($app.id))"
            foreach ($cred in $app.federatedIdentityCredentials) {
                $hasMutableSubject = $false
                # check if its a subject or a claimsMatchingExpression
                $subject = $cred.subject ?? $cred.claimsMatchingExpression.value
                # GitHub
                if ($cred.issuer -eq 'https://token.actions.githubusercontent.com') {
                    $applicableCount++
                    $hasMutableSubject = $subject -notmatch $gitHubImmutableOidcClaims
                } elseif ($subject -match $gitLabOidcIdentifiers) {
                    $applicableCount++
                    $hasMutableSubject = $subject -notmatch $gitLabImmutableOidcClaims
                } else {
                    Write-Verbose "Found federated credential with non GitHub or GitLab claims $subject (issuer: $($cred.issuer))"
                }
                if ($hasMutableSubject) {
                    $finding = [pscustomobject]@{
                        Application   = $app.displayName
                        ApplicationId = $app.id
                        Credential    = $cred.name
                        Issuer        = $cred.issuer
                        Subject       = $subject
                    }
                    $findings.Add($finding)
                }
            }
        }
        $resultMarkdown = "Scanned $($apps.Count) applications. "
        $result = $findings.Count -eq 0 -and $applicableCount -gt 0

        if ($result) {
            $resultMarkdown += 'No GitHub or GitLab federated identity credentials were found with subjects missing the checked immutable identifier markers.'
        } elseif ($applicableCount -eq 0) {
            Add-MtTestResultDetail -SkippedBecause NotApplicable -Description 'No applications with GitHub or GitLab federated credentials were found.'
            return $null
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
        return $result
    } else {
        Add-MtTestResultDetail -SkippedBecause NotApplicable -Description 'No applications with federated credentials were found.'
        return $null
    }
}
