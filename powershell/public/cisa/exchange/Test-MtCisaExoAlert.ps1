<#
.SYNOPSIS
    Checks state of alerts

.DESCRIPTION
    Alerts SHALL be enabled.

.EXAMPLE
    Test-MtCisaExoAlert

    Returns true if alerts enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaExoAlert
#>
function Test-MtCisaExoAlert {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }elseif($null -eq (Get-MtLicenseInformation -Product Mdo)){
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }

    $alerts = Get-MtExo -Request ProtectionAlert

    $cisaAlerts = @(
        "be215649-fba8-4339-9ddd-05991a43b948", #Suspicious email sending patterns detected
        "8bb9c6c8-dc12-40e1-5bb8-08da05b13393", #Suspicious connector activity
        "bfd48f06-0865-41a6-85ff-adb746423ebf", #Suspicious Email Forwarding Activity
        "37a4e852-e711-45ca-b0f4-b076bae3adfd", #Messages have been delayed
        "5ed2d687-9bd3-49e7-9b56-b7dc0d9af5cb", #Tenant restricted from sending unprovisioned email
        "a7032ff5-7eee-412b-805b-d1295c7e0932", #Tenant restricted from sending email
        "a74bb32a-541b-47fb-adfd-f8c62ce3d59b"  #A potentially malicious URL click was detected
    )

    $filterAlerts = $alerts | Where-Object { `
        $_.ExchangeObjectId -in $cisaAlerts
    }

    $resultAlerts = $alerts | Where-Object { `
        $_.ExchangeObjectId -in $cisaAlerts -and `
        $_.NotificationEnabled
    }

    $testResult = (($resultAlerts|Measure-Object).Count -eq ($cisaAlerts|Measure-Object).Count)

    $portalLink = "https://security.microsoft.com/alertpoliciesv2"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [alerts configured]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [alerts configured]($portalLink).`n`n%TestResult%"
    }

    $result = "| Alert Name | Alert Result |`n"
    $result += "| --- | --- |`n"
    foreach($item in $filterAlerts | Sort-Object -Property Identity){
        if($item.Guid -in $resultAlerts.Guid){
            $result += "| $($item.Identity) | $passResult |`n"
        }else{
            $result += "| $($item.Identity) | $failResult |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}