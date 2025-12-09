function Test-AzdoOrganizationStorageUsage {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $StorageUsage = Get-ADOPSOrganizationCommerceMeterUsage -MeterId '3efc2e47-d73e-4213-8368-3a8723ceb1cc'
    $availableQuantity = $StorageUsage.availableQuantity

    if ($availableQuantity -lt [double]::Parse('0.1')) {
        $resultMarkdown = "Your storage is exceeding the usage limit or close to. '$availableQuantity' GB available."
        $result = $false
    }
    else {
        $resultMarkdown = 
        @'
        Well done. You are not exceeding or approaching your storage usage limit.
        Current usage: {0} GB
        Max quantity: {1} GB
'@ -f $StorageUsage.currentQuantity, $StorageUsage.maxQuantity
        $result = $true
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'High'

    return $result
}