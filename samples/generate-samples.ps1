. ../powershell/public/core/Merge-MtMaesterResult.ps1
. ../powershell/public/core/Get-MtHtmlReport.ps1

function New-SampleTenant {
    param([string]$TenantId, [string]$TenantName, [string]$Account, [array]$Tests, [array]$Blocks, [int]$Total, [int]$Passed, [int]$Failed, [int]$Skipped)
    [PSCustomObject]@{
        TenantId          = $TenantId
        TenantName        = $TenantName
        TenantLogos       = [PSCustomObject]@{ Banner = ""; Square = "" }
        Result            = if ($Failed -gt 0) { "Failed" } else { "Passed" }
        TotalCount        = $Total
        PassedCount       = $Passed
        FailedCount       = $Failed
        ErrorCount        = 0
        SkippedCount      = $Skipped
        InvestigateCount  = 0
        NotRunCount       = 0
        ExecutedAt        = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        TotalDuration     = "00:02:15"
        UserDuration      = "00:02:00"
        DiscoveryDuration = "00:00:10"
        FrameworkDuration = "00:00:05"
        CurrentVersion    = "2.1.0"
        LatestVersion     = "2.1.0"
        Account           = $Account
        SystemInfo        = [PSCustomObject]@{ MachineName = "AZP-AGENT-01"; OSPlatform = "Linux"; OSVersion = "Ubuntu 22.04" }
        PowerShellInfo    = [PSCustomObject]@{ Version = "7.4.6"; Edition = "Core" }
        LoadedModules     = @(
            [PSCustomObject]@{ Name = "Maester"; Version = "2.1.0" }
            [PSCustomObject]@{ Name = "Microsoft.Graph.Authentication"; Version = "2.25.0" }
        )
        InvokeCommand     = "Invoke-Maester"
        MgContext         = [PSCustomObject]@{ TenantId = $TenantId; Scopes = @("Directory.Read.All", "Policy.Read.All") }
        Tests             = $Tests
        Blocks            = $Blocks
        MaesterConfig     = [PSCustomObject]@{
            ConfigSource   = "maester-config.$TenantId.json"
            GlobalSettings = [PSCustomObject]@{
                EmergencyAccessAccounts = @(
                    [PSCustomObject]@{ Type = "User"; UserPrincipalName = "BreakGlass1@$($TenantName -replace ' ','').onmicrosoft.com" }
                    [PSCustomObject]@{ Type = "User"; UserPrincipalName = "BreakGlass2@$($TenantName -replace ' ','').onmicrosoft.com" }
                )
            }
            TestSettings = @(
                [PSCustomObject]@{ Id = "MT.1001"; Severity = "High"; Title = "Global admin count should be limited" }
                [PSCustomObject]@{ Id = "MT.1002"; Severity = "Critical"; Title = "MFA should be required for all users" }
                [PSCustomObject]@{ Id = "MT.1003"; Severity = "High"; Title = "Legacy authentication should be blocked" }
            )
        }
        EndOfJson         = "EndOfJson"
    }
}

function New-TestResult {
    param([int]$Index, [string]$Id, [string]$Title, [string]$Result, [string]$Severity, [string]$Block, [string]$Description, [string]$TestResult)
    $err = if ($Result -eq "Failed") { @([PSCustomObject]@{ Message = $TestResult }) } else { @() }
    [PSCustomObject]@{
        Index        = $Index; Id = $Id; Title = $Title
        Name         = "${Id}: $Title"; Result = $Result
        Severity     = $Severity; Tag = @($Id, "Security"); Block = $Block
        Duration     = "00:00:02"; ErrorRecord = $err
        ResultDetail = [PSCustomObject]@{ TestDescription = $Description; TestResult = $TestResult }
    }
}

# --- Single tenant report ---
$singleTests = @(
    (New-TestResult 1  "MT.1001" "Global admin count should be limited"          "Passed"  "High"     "Maester/Entra" "Checks global admin count"               "Found 3 global admins")
    (New-TestResult 2  "MT.1002" "MFA should be required for all users"          "Passed"  "Critical" "Maester/Entra" "Verifies MFA enforcement"                "MFA policy active")
    (New-TestResult 3  "MT.1003" "Legacy authentication should be blocked"       "Passed"  "High"     "Maester/Entra" "Checks legacy auth"                      "Blocked via CA policy")
    (New-TestResult 4  "MT.1004" "Self-service password reset enabled"           "Passed"  "Medium"   "Maester/Entra" "Verifies SSPR"                           "SSPR enabled")
    (New-TestResult 5  "MT.1005" "Password expiration policy"                    "Failed"  "High"     "Maester/Entra" "Passwords should never expire"           "Password expiration: 90 days. Expected: Never")
    (New-TestResult 6  "MT.1006" "Guest user access should be restricted"        "Passed"  "High"     "Maester/Entra" "Guest access"                            "Guest access restricted")
    (New-TestResult 7  "MT.1007" "Security defaults disabled with CA"            "Passed"  "Medium"   "Maester/Entra" "Security defaults"                       "Security defaults disabled, 8 CA policies active")
    (New-TestResult 8  "MT.1008" "App registrations restricted"                  "Passed"  "Medium"   "Maester/Entra" "App registration"                        "Restricted to admins")
    (New-TestResult 9  "MT.1009" "Consent workflow enabled"                      "Passed"  "Medium"   "Maester/Entra" "Admin consent workflow"                  "Consent workflow enabled")
    (New-TestResult 10 "MT.1010" "Named locations configured"                    "Failed"  "Medium"   "Maester/Entra" "At least one named location should exist" "Found 0 named locations. Expected: at least 1")
    (New-TestResult 11 "MT.1011" "Break glass accounts exist"                    "Passed"  "Critical" "Maester/Entra" "Emergency access accounts"               "2 emergency access accounts found")
    (New-TestResult 12 "CIS.M365.1.1.1" "Cloud-only admin accounts"             "Skipped" "High"     "Maester/CIS"   "Admin accounts should be cloud-only"     "Skipped: requires premium license")
)
$singleBlocks = @(
    [PSCustomObject]@{ Name = "Maester/Entra"; PassedCount = 8; FailedCount = 2; SkippedCount = 0; TotalCount = 10 }
    [PSCustomObject]@{ Name = "Maester/CIS"; PassedCount = 0; FailedCount = 0; SkippedCount = 1; TotalCount = 1 }
)
$singleTenant = New-SampleTenant "a1b2c3d4-e5f6-7890-abcd-ef1234567890" "Contoso Production" "maester-sa@contoso.com" $singleTests $singleBlocks 12 9 2 1
$singleTenant.MaesterConfig.ConfigSource = "maester-config.json"

Write-Host "Generating single-tenant report..."
$html = Get-MtHtmlReport -MaesterResults $singleTenant
$html | Out-File -FilePath "$PSScriptRoot/sample-report-single-tenant.html" -Encoding UTF8
Write-Host "Saved: sample-report-single-tenant.html"

# --- Multi-tenant report (3 tenants) ---

# Tenant 1: Contoso Production (mostly passing, includes AzDO tests)
$t1Tests = @(
    (New-TestResult 1  "MT.1001" "Global admin count should be limited"     "Passed" "High"     "Maester/Entra"       "Checks global admin count"  "Found 3 global admins")
    (New-TestResult 2  "MT.1002" "MFA should be required for all users"     "Passed" "Critical" "Maester/Entra"       "Verifies MFA enforcement"   "MFA policy active")
    (New-TestResult 3  "MT.1003" "Legacy authentication should be blocked"  "Passed" "High"     "Maester/Entra"       "Checks legacy auth"         "Blocked via CA policy")
    (New-TestResult 4  "MT.1004" "Self-service password reset enabled"      "Passed" "Medium"   "Maester/Entra"       "Verifies SSPR"              "SSPR enabled")
    (New-TestResult 5  "MT.1005" "Password expiration policy"               "Failed" "High"     "Maester/Entra"       "Passwords should never expire" "Password expiration: 90 days")
    (New-TestResult 6  "MT.1006" "Guest user access restricted"             "Passed" "High"     "Maester/Entra"       "Guest access"               "Guest access restricted")
    (New-TestResult 7  "MT.1007" "Security defaults disabled with CA"       "Passed" "Medium"   "Maester/Entra"       "Security defaults"          "Disabled, 8 CA policies")
    (New-TestResult 8  "MT.1008" "App registrations restricted"             "Passed" "Medium"   "Maester/Entra"       "App registration"           "Restricted to admins")
    (New-TestResult 9  "AZDO.1000" "Third-party OAuth access disabled"      "Passed" "High"     "Maester/AzureDevOps" "OAuth policy"               "OAuth disabled")
    (New-TestResult 10 "AZDO.1001" "SSH authentication disabled"            "Passed" "High"     "Maester/AzureDevOps" "SSH policy"                 "SSH disabled")
    (New-TestResult 11 "AZDO.1002" "Auditing enabled"                       "Passed" "High"     "Maester/AzureDevOps" "Audit policy"               "Auditing enabled")
    (New-TestResult 12 "AZDO.1030" "Project Collection Administrators"      "Failed" "Critical" "Maester/AzureDevOps" "PCA membership"             "Found 8 members. Expected: 5 or fewer")
)
$t1Blocks = @(
    [PSCustomObject]@{ Name = "Maester/Entra"; PassedCount = 7; FailedCount = 1; SkippedCount = 0; TotalCount = 8 }
    [PSCustomObject]@{ Name = "Maester/AzureDevOps"; PassedCount = 3; FailedCount = 1; SkippedCount = 0; TotalCount = 4 }
)
$tenant1 = New-SampleTenant "a1b2c3d4-e5f6-7890-abcd-ef1234567890" "Contoso Production" "maester-sa@contoso.com" $t1Tests $t1Blocks 12 10 2 0

# Tenant 2: Fabrikam Development (more failures)
$t2Tests = @(
    (New-TestResult 1 "MT.1001" "Global admin count should be limited"     "Failed" "High"     "Maester/Entra" "Checks global admin count"     "Found 7 global admins. Expected: 2-4")
    (New-TestResult 2 "MT.1002" "MFA should be required for all users"     "Passed" "Critical" "Maester/Entra" "Verifies MFA enforcement"       "MFA policy active")
    (New-TestResult 3 "MT.1003" "Legacy authentication should be blocked"  "Failed" "High"     "Maester/Entra" "Checks legacy auth"             "Legacy auth not blocked")
    (New-TestResult 4 "MT.1004" "Self-service password reset enabled"      "Failed" "Medium"   "Maester/Entra" "Verifies SSPR"                  "SSPR not enabled")
    (New-TestResult 5 "MT.1005" "Password expiration policy"               "Passed" "High"     "Maester/Entra" "Passwords should never expire"  "Set to never expire")
    (New-TestResult 6 "MT.1006" "Guest user access restricted"             "Failed" "High"     "Maester/Entra" "Guest access"                   "Guest access unrestricted")
    (New-TestResult 7 "MT.1007" "Security defaults disabled with CA"       "Passed" "Medium"   "Maester/Entra" "Security defaults"              "Security defaults disabled")
    (New-TestResult 8 "MT.1008" "App registrations restricted"             "Passed" "Medium"   "Maester/Entra" "App registration"               "Restricted to admins")
)
$t2Blocks = @(
    [PSCustomObject]@{ Name = "Maester/Entra"; PassedCount = 4; FailedCount = 4; SkippedCount = 0; TotalCount = 8 }
)
$tenant2 = New-SampleTenant "b2c3d4e5-f6a7-8901-bcde-f12345678901" "Fabrikam Development" "maester@fabrikam.dev" $t2Tests $t2Blocks 8 4 4 0

# Tenant 3: Woodgrove China (sovereign cloud, good posture)
$t3Tests = @(
    (New-TestResult 1 "MT.1001" "Global admin count should be limited"     "Passed"  "High"     "Maester/Entra" "Checks global admin count"     "Found 2 global admins")
    (New-TestResult 2 "MT.1002" "MFA should be required for all users"     "Passed"  "Critical" "Maester/Entra" "Verifies MFA enforcement"       "MFA policy active")
    (New-TestResult 3 "MT.1003" "Legacy authentication should be blocked"  "Passed"  "High"     "Maester/Entra" "Checks legacy auth"             "Blocked via CA policy")
    (New-TestResult 4 "MT.1004" "Self-service password reset enabled"      "Passed"  "Medium"   "Maester/Entra" "Verifies SSPR"                  "SSPR enabled")
    (New-TestResult 5 "MT.1005" "Password expiration policy"               "Passed"  "High"     "Maester/Entra" "Passwords should never expire"  "Set to never expire")
    (New-TestResult 6 "MT.1006" "Guest user access restricted"             "Passed"  "High"     "Maester/Entra" "Guest access"                   "Guest access restricted")
    (New-TestResult 7 "CIS.M365.1.1.1" "Cloud-only admin accounts"        "Skipped" "High"     "Maester/CIS"   "Admin accounts should be cloud-only" "Skipped: not available in China cloud")
)
$t3Blocks = @(
    [PSCustomObject]@{ Name = "Maester/Entra"; PassedCount = 6; FailedCount = 0; SkippedCount = 0; TotalCount = 6 }
    [PSCustomObject]@{ Name = "Maester/CIS"; PassedCount = 0; FailedCount = 0; SkippedCount = 1; TotalCount = 1 }
)
$tenant3 = New-SampleTenant "c3d4e5f6-a7b8-9012-cdef-123456789012" "Woodgrove China" "maester@woodgrove.cn" $t3Tests $t3Blocks 7 6 0 1

$merged = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2, $tenant3)

Write-Host "Generating multi-tenant report..."
$html = Get-MtHtmlReport -MaesterResults $merged
$html | Out-File -FilePath "$PSScriptRoot/sample-report-multi-tenant.html" -Encoding UTF8
Write-Host "Saved: sample-report-multi-tenant.html"

Write-Host "Done! Open the HTML files in a browser to review."
