<#
.SYNOPSIS
    Get the icon representation for a specific privileged classification level.
.EXAMPLE
    PS C:\> Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName 'ControlPlane'
    Returns the icon for the Control Plane classification.
.INPUTS
    System.String
#>
function Get-MtXspmPrivilegedClassificationIcon {
    param (
        [Parameter(Mandatory = $true)]
        [object]$AdminTierLevelName
    )
    #region Classification icon
    if ($AdminTierLevelName -contains 'ControlPlane') {
        $AdminTierLevelIcon = "🔐"
    } elseif ($AdminTierLevelName -contains 'ManagementPlane') {
        $AdminTierLevelIcon = "☁️"
    } elseif ($AdminTierLevelName -contains 'WorkloadPlane') {
        $AdminTierLevelIcon = "⚙️"
    } elseif ($AdminTierLevelName -contains 'High') {
        $AdminTierLevelIcon = "⚠️"
    } else {
        $AdminTierLevelIcon = "ℹ️"
    }
    return $AdminTierLevelIcon
    #endregion
}