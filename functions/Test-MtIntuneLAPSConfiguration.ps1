function Test-MtIntuneLAPSConfiguration {
    param (
        [string]$ApiVersion = "v1.0"
    )

    $uri = "/deviceManagement/configurationPolicies"
    $response = Invoke-MtGraphRequest -RelativeUri $uri -ApiVersion $ApiVersion

    if ($response -and $response.value) {
        foreach ($policy in $response.value) {
            if ($policy.displayName -like "*LAPS*" -and $policy.odataType -eq "#microsoft.graph.deviceManagementConfigurationPolicy") {
                Add-MtTestResultDetail -Name "LAPS Policy Found" -Detail $policy.displayName
                return $true
            }
        }
    }

    Add-MtTestResultDetail -Name "LAPS Policy Missing" -Detail "No LAPS Configuration policy found."
    return $false
}