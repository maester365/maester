function Test-MtCisGitHubRepositoryCreationLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.2: Ensure repository creation is limited to specific members.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 section 1.2.2 marks this recommendation as
    Manual. This test automates the organization member-privileges fields
    exposed by GET /orgs/{org}. Public and private repository creation decide
    the test result; internal repository creation is shown as informational
    evidence when GitHub returns it.

    .EXAMPLE
    Test-MtCisGitHubRepositoryCreationLimited

    Returns true when members cannot create public or private repositories.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubRepositoryCreationLimited
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection GitHub)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGitHub
        return $null
    }

    try {
        Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.2.2.'
        $org = Get-MtGitHubOrganization
        $requiredFields = @('members_can_create_public_repositories', 'members_can_create_private_repositories')
        $missingFields = @($requiredFields | Where-Object { -not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $_) })

        if ($missingFields.Count -gt 0) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field(s): $($missingFields -join ', '). These fields are required to evaluate CIS.GH.1.2.2 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $checks = @(
            [PSCustomObject]@{
                Field    = 'members_can_create_public_repositories'
                Actual   = $org.members_can_create_public_repositories
                Expected = $false
                Decisive = $true
                Pass     = $org.members_can_create_public_repositories -eq $false
            }
            [PSCustomObject]@{
                Field    = 'members_can_create_private_repositories'
                Actual   = $org.members_can_create_private_repositories
                Expected = $false
                Decisive = $true
                Pass     = $org.members_can_create_private_repositories -eq $false
            }
        )

        $internalRepositoryNote = $null
        if (Test-MtGitHubObjectProperty -InputObject $org -PropertyName 'members_can_create_internal_repositories') {
            $internalRepositoryCheck = [PSCustomObject]@{
                Field    = 'members_can_create_internal_repositories'
                Actual   = $org.members_can_create_internal_repositories
                Expected = 'Informational'
                Decisive = $false
                Pass     = $true
            }
            $checks = $checks + $internalRepositoryCheck
            $internalRepositoryNote = "The internal-repository row is informational. CIS GH 1.2.2's literal audit covers public and private only."
        }

        $result = @($checks | Where-Object { $_.Decisive -eq $true -and $_.Pass -ne $true }).Count -eq 0
        $detailRows = $checks | ForEach-Object {
            "| ``$($_.Field)`` | ``$($_.Actual)`` | ``$($_.Expected)`` |"
        }
        $legacyValue = if (Test-MtGitHubObjectProperty -InputObject $org -PropertyName 'members_can_create_repositories') {
            "Umbrella legacy field ``members_can_create_repositories`` was returned as ``$($org.members_can_create_repositories)``. The granular fields above are the decisive checks."
        } else {
            "Umbrella legacy field ``members_can_create_repositories`` was not returned. The granular fields above are the decisive checks."
        }

        $resultMarkdown = @"
CIS.GH.1.2.2 automated evidence from ``GET /orgs/{org}``.

| Field | Actual | Expected |
| --- | --- | --- |
$($detailRows -join "`n")

$internalRepositoryNote

$legacyValue
"@
        Add-MtTestResultDetail -Result $resultMarkdown
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
