<#
.SYNOPSIS
    Checks if Global Admins are cloud users

.DESCRIPTION
    Ensure Administrative accounts are separate and cloud-only
    CIS Microsoft 365 Foundations Benchmark v3.1.0

.EXAMPLE
    Test-MtCisCloudAdmin

    Returns true if no global admins are hybrid sync

.LINK
    https://maester.dev/docs/commands/Test-MtCisCloudAdmin
#>
function Test-MtCisCloudAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Getting Global Admin role"
    $role = Get-MtRole | Where-Object {
        $_.id -eq "62e90394-69f5-4237-9190-012177145e10"
    } # Global Administrator

    Write-Verbose "Getting role members"
    $assignments = Get-MtRoleMember -roleId $role.id

    Write-Verbose "Filtering for users"
    $globalAdministrators = $assignments | Where-Object {
        $_.'@odata.type' -eq "#microsoft.graph.user"
    }

    $userIds = @($globalAdministrators.Id)

    Write-Verbose "Requesting users onPremisesSyncEnabled property"
    $users = Invoke-MtGraphRequest -RelativeUri "users" -UniqueId $userIds -Select id, displayName, onPremisesSyncEnabled

    Write-Verbose "Filtering users for onPremisesSyncEnabled"
    $result = $users | Where-Object {`
            $_.onPremisesSyncEnabled -eq $true
    }

    $testResult = ($result | Measure-Object).Count -eq 0

    $sortSplat = @{
        Property = @(
            @{
                Expression = "onPremisesSyncEnabled"
                Descending = $true
            },
            @{
                Expression = "displayName"
            }
        )
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no hybrid Global Administrators:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant has 1 or more hybrid Global Administrators:`n`n%TestResult%"
    }

    $resultMd = "| Display Name | Cloud Only |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $users | Sort-Object @sortSplat) {
        $itemResult = "❌ Fail"
        if ($item.id -notin $result.id) {
            $itemResult = "✅ Pass"
        }
        $resultMd += "| $($item.displayName) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}