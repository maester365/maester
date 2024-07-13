<#
.SYNOPSIS
    Tests your environment for compliance with the specified EIDSCA control

.DESCRIPTION
    Validates your environment against the specified EIDSCA control by comparing MS Graph result with the recommended value.

.EXAMPLE
    Test-MtEidscaControl -Id AP01

    Returns the result of the EIDSCA AP01 control
#>

Function Test-MtEidscaControl {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Id for the EIDSCA control to test
        [Parameter(Mandatory)]
        [ValidateSet('AP01','AP04','AP05','AP06','AP07','AP08','AP09','AP10','AP14','CP01','CP03','CP04','PR01','PR02','PR03','PR05','PR06','ST08','ST09','AG01','AG02','AG03','AM01','AM02','AM03','AM04','AM06','AM07','AM09','AM10','AF01','AF02','AF03','AF04','AF05','AF06','AT01','AT02','AV01','CR01','CR02','CR03','CR04')]
        [string]
        $CheckId
    )

    & "Test-MtEidsca$CheckId"
}
