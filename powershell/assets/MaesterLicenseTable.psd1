# Licence tokens for [MaesterTest(CompatibleLicense = ...)] (Maester 3.0 design, section 6).
#
# A token is a Microsoft service plan name. Each resolves to the IDs that Get-MtLicenseInformation
# matched in Maester 2.x, including government, education and volume variants, so the engine's
# licence gate gives the same verdict as the guards it replaces. A tenant has a token when any of its
# enabled SKUs (capabilityStatus Enabled) contains one of the ServicePlanIds or is one of the SkuIds.
# A token not listed here (custom or ported tests) is matched literally against the tenant's service
# plan names. LegacySkipCode is the 2.x -SkippedBecause code written to ResultDetail.
@{
    SchemaVersion = '1.0'
    Tokens        = @{
        # Entra ID P1 or better (2.x: Get-MtLicenseInformation EntraID is not Free).
        AAD_PREMIUM               = @{ ServicePlanIds = @('41781fb2-bc02-4b7c-bd55-b576c07bb09d', 'eec0eb4f-6444-4f95-aba0-50c24d67f998', 'e866a266-3cff-43a3-acca-0c90a7e00c8b'); LegacySkipCode = 'NotLicensedEntraIDP1' }
        AAD_PREMIUM_P2            = @{ ServicePlanIds = @('eec0eb4f-6444-4f95-aba0-50c24d67f998'); LegacySkipCode = 'NotLicensedEntraIDP2' }
        Entra_Identity_Governance = @{ ServicePlanIds = @('e866a266-3cff-43a3-acca-0c90a7e00c8b'); LegacySkipCode = 'NotLicensedEntraIDGovernance' }
        # Workload ID P1 or P2.
        AAD_WRKLDID_P1            = @{ ServicePlanIds = @('84c289f0-efcb-486f-8581-07f44fc9efad', '7dc0e92d-bf15-401d-907e-0884efe7c760'); LegacySkipCode = 'NotLicensedEntraWorkloadID' }
        AAD_WRKLDID_P2            = @{ ServicePlanIds = @('7dc0e92d-bf15-401d-907e-0884efe7c760'); LegacySkipCode = 'NotLicensedEntraWorkloadID' }
        EOP_ENTERPRISE            = @{ ServicePlanIds = @('326e2b78-9d27-42c9-8509-46c827743a17'); SkuIds = @('326e2b78-9d27-42c9-8509-46c827743a17'); LegacySkipCode = 'NotLicensedEop' }
        # Exchange Online DLP: Exchange Online Plan 2 (incl. GOV), the DLP plan, or Microsoft 365 Business Premium.
        EXCHANGE_DLP              = @{
            ServicePlanIds = @('efb87545-963c-4e0d-99df-69c6916d9eb0', '8c3069c0-ccdb-44be-ab77-986203a67df2', '9bec7e34-c9fa-40b7-a9d1-bd6d1165c7ed')
            SkuIds         = @('cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46', 'a3f586b6-8cce-4d9b-99d6-55238397f77a')
            LegacySkipCode = 'NotLicensedExoDlp'
        }
        # Defender for Office 365 Plan 2 (incl. GOV).
        THREAT_INTELLIGENCE       = @{ ServicePlanIds = @('8e0c0a52-6a6c-4d40-8370-dd62790dcd70', '900018f1-0cdb-4ecb-94d4-90281760fdc6'); SkuIds = @('8e0c0a52-6a6c-4d40-8370-dd62790dcd70', '900018f1-0cdb-4ecb-94d4-90281760fdc6'); LegacySkipCode = 'NotLicensedMdo' }
        # Defender for Office 365 Plan 1 or Plan 2 (incl. GOV).
        ATP_ENTERPRISE            = @{ ServicePlanIds = @('f20fedf3-f3c3-43c3-8267-2bfdd51c0939', '493ff600-6a2b-4db6-ad37-a7d4eb214516', '8e0c0a52-6a6c-4d40-8370-dd62790dcd70', '900018f1-0cdb-4ecb-94d4-90281760fdc6'); LegacySkipCode = 'NotLicensedMdoP1' }
        M365_ADVANCED_AUDITING    = @{ ServicePlanIds = @('2f442157-a11c-46b9-ae5b-6e39ff4e5849'); SkuIds = @('2f442157-a11c-46b9-ae5b-6e39ff4e5849'); LegacySkipCode = 'NotLicensedAdvAudit' }
        # Any Exchange Online mailbox licence.
        EXCHANGE_S_STANDARD       = @{
            ServicePlanIds = @('efb87545-963c-4e0d-99df-69c6916d9eb0', '9aaf7827-d63c-4b61-89c3-182f06f82e5c', '8c3069c0-ccdb-44be-ab77-986203a67df2', 'e9b4930a-925f-45e2-ac2a-3f7788ca6fdd',
                '4a82b400-a79f-41a4-b4e2-e94f5787b113', '1126bef5-da20-4f07-b45e-ad25d2581aa8', '90b5e015-709a-4b8b-b08e-3200f994494c', '176a09a6-7ec5-4039-ac02-b2791c6ba793')
            LegacySkipCode = 'NotLicensedExoDlp'
        }
        # Any Defender XDR workload: Endpoint P2, Office 365 P2, Identity or Cloud Apps.
        DEFENDER_XDR              = @{ ServicePlanIds = @('871d91ec-ec1a-452b-a83f-bd76c7d770ef', '8e0c0a52-6a6c-4d40-8370-dd62790dcd70', '14ab5db5-e6c4-4b20-b4bc-13e36fd2227f', '2e2ddb96-6af9-4b1d-a3f0-d6ecfd22edb2'); SkuIds = @('871d91ec-ec1a-452b-a83f-bd76c7d770ef', '8e0c0a52-6a6c-4d40-8370-dd62790dcd70', '14ab5db5-e6c4-4b20-b4bc-13e36fd2227f', '2e2ddb96-6af9-4b1d-a3f0-d6ecfd22edb2'); LegacySkipCode = 'NotLicensedDefenderXDR' }
        LOCKBOX_ENTERPRISE        = @{ ServicePlanIds = @('9f431833-0334-42de-a7dc-70aa40db46db', '3ec18638-bd4c-4d3b-8905-479ed636b83e'); LegacySkipCode = 'NotLicensedCustomerLockbox' }
        INTUNE_A                  = @{
            ServicePlanIds = @('c1ec4a95-1f05-45b3-a911-aa3fa01094f5', 'd216f254-796f-4dab-bbfa-710686e646b9', '3e170737-c728-4eae-bbb9-3f3360f7184c', 'da24caf9-af8e-485c-b7c8-e73336da2693',
                '2b317a4a-77a6-4188-9437-b68a77b4e2c6', '2c21e77a-e0d6-4570-b38a-7ff2dc17d2ca', 'b4288abe-01be-47d9-ad20-311d6e83fc24', 'e6025b08-2fa5-4313-bd0a-7e5ffca32958')
            LegacySkipCode = 'NotLicensedIntune'
        }
    }
}
