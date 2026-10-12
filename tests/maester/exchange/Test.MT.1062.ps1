function Test-MtExoRejectDirectSend {
    <#
    .SYNOPSIS
    Checks if direct send is configured to reject

    .DESCRIPTION
    Attackers can exploit direct send to send spam or phishing emails without authentication.
    Direct Send covers anonymous messages (unauthenticated messages) sent from your own domain
    to your organization's mailboxes using the tenant MX

    .EXAMPLE
    Test-MtExoRejectDirectSend

    Returns true if direct send is configured to reject

    .LINK
    https://maester.dev/docs/commands/Test-MtExoRejectDirectSend
    #>
    [MaesterTest(
        Id = 'MT.1062',
        Title = 'Ensure Direct Send is set to be rejected',
        Product = 'exchange',
        Feature = 'mail-flow',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = 'nist-800-53-r5:CM-7',
        Service = 'ExchangeOnline',
        Author = 'bastienperez'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Getting Organization..."
    $organizationConfig = Get-MtExo -Request OrganizationConfig

    $result = $organizationConfig.RejectDirectSend

    if ($result) {
        $testResultMarkdown = "Well done. RejectDirectSend is ``$($result)``.`n`n"
    } else {
        $testResultMarkdown = "``RejectDirectSend`` should be ``True``. RejectDirectSend is ``$($result)``.`n`n"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    # 2.x failed the test whenever the value was not $true (including a missing value).
    return ($result -eq $true)
}
