function Test-CntSampleMfaRequired {
    <#
    .SYNOPSIS
    Checks that the sample service requires MFA.
    #>
    [MaesterTest(
        Id       = 'MP.CNT.1001',
        Title    = 'The sample service requires MFA',
        Severity = 'High',
        Service  = 'CNT.Sample'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $settings = Get-CntSampleSetting
    $passed = [bool]$settings.MfaRequired
    Add-MtTestResultDetail -Result $(if ($passed) { 'MFA is required.' } else { 'MFA is not required.' })
    $passed
}
