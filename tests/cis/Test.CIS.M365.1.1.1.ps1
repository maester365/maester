function Test-MtCisCloudAdmin {
    <#
    .SYNOPSIS
    Checks if administrative role members are cloud-only

    .DESCRIPTION
    Ensure Administrative accounts are cloud-only
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.1.1, L1)

    .EXAMPLE
    Test-MtCisCloudAdmin

    Returns true if no administrative role members are hybrid synced

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCloudAdmin
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.1.1',
        Title = 'Ensure Administrative accounts are cloud-only',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'administrative-accounts',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.002', 'T1078.004', 'T1556.007'),
        Control = ('cis-m365:1.1.1', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = 'NZLostboy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting administrative roles'
    $roles = Get-MtRole | Where-Object {
        $_.displayName -like '*Administrator*' -or $_.displayName -eq 'Global Reader'
    }

    Write-Verbose 'Getting role members'
    $assignments = Get-MtRoleMember -RoleId $roles.id

    Write-Verbose 'Filtering administrative role members for users'
    $administrativeUsers = @($assignments | Where-Object {
        $_.'@odata.type' -eq '#microsoft.graph.user'
    } | Sort-Object id -Unique)

    $userIds = @($administrativeUsers.Id)

    $users = @()
    if ($userIds.Count -gt 0) {
        Write-Verbose 'Requesting users onPremisesSyncEnabled property'
        $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId $userIds -Select id, displayName, onPremisesSyncEnabled)

        $returnedUserIds = @($users | ForEach-Object { [string]$_.id })
        $missingUserIds = @($userIds | Where-Object { $_ -notin $returnedUserIds })
        if ($missingUserIds.Count -gt 0) {
            throw "Microsoft Graph did not return user details for all administrative role members. Missing user IDs: $($missingUserIds -join ', ')."
        }

        $usersMissingSyncStatus = @($users | Where-Object {
            $_.PSObject.Properties.Name -notcontains 'onPremisesSyncEnabled'
        })
        if ($usersMissingSyncStatus.Count -gt 0) {
            $missingSyncStatusIds = @($usersMissingSyncStatus | ForEach-Object { [string]$_.id })
            throw "Microsoft Graph did not return onPremisesSyncEnabled for administrative role members: $($missingSyncStatusIds -join ', ')."
        }
    }

    Write-Verbose 'Filtering users for onPremisesSyncEnabled'
    $result = @($users | Where-Object {
        $_.onPremisesSyncEnabled -eq $true
    })

    $testResult = $result.Count -eq 0

    $sortSplat = @{
        Property = @(
            @{
                Expression = 'onPremisesSyncEnabled'
                Descending = $true
            },
            @{
                Expression = 'displayName'
            }
        )
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no hybrid-synced users in administrative roles:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has one or more hybrid-synced users in administrative roles:`n`n%TestResult%"
    }

    $resultMd = "| Display Name | Cloud Only |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $users | Sort-Object @sortSplat) {
        $itemResult = '❌ Fail'
        if ($item.id -notin $result.id) {
            $itemResult = '✅ Pass'
        }
        $resultMd += "| $(Get-MtSafeMarkdown $item.displayName) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
