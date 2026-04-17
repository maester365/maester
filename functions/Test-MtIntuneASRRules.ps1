function Test-MtIntuneASRRules {
    param (
        [string]$ApiVersion = "v1.0"
    )

    $uri = "/deviceManagement/intents"
    $response = Invoke-MtGraphRequest -RelativeUri $uri -ApiVersion $ApiVersion

    if ($response -and $response.value) {
        foreach ($intent in $response.value) {
            if ($intent.displayName -like "*ASR*" -and $intent.odataType -eq "#microsoft.graph.deviceManagementIntent") {
                Add-MtTestResultDetail -Name "ASR Rules Found" -Detail $intent.displayName
                return $true
            }
        }
    }

    Add-MtTestResultDetail -Name "ASR Rules Missing" -Detail "No ASR Rules found."
    return $false
}