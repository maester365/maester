function Test-MtDisaIntuneWipeApproval {
    <#
    .SYNOPSIS
    Checks that an Intune Multi Admin Approval policy protects device wipes.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop and Mobile STIG (V-285327, CAT I): The Intune service must be configured to implement Multi-Admin Approval (MAA) for wiping managed devices.

    This test runs MT.1096 (Test-MtOperationApprovalPolicies). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneWipeApproval

    Returns the result of MT.1096 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-285327
    #>
    [MaesterTest(
        Id = 'DISA.V-285327',
        Title = 'The Intune service must be configured to implement Multi-Admin Approval (MAA) for wiping managed devices.',
        Product = 'intune',
        Feature = 'tenant-administration',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1072', 'T1078.004'),
        Control = 'disa-stig-intune-mdm:V-285327',
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The Multi Admin Approval policy types that protect a device wipe.
        [string[]] $RequiredPolicyTypes = ('deviceWipe', 'deviceAction')
    )

    return Test-MtOperationApprovalPolicies -RequiredPolicyTypes $RequiredPolicyTypes
}
