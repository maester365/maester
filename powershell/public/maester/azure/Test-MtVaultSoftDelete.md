Soft delete ensures that backup items and recovery points are retained for a period after deletion. This protects against accidental or malicious deletion of backups.

Ensure that all Recovery Services Vaults across all subscriptions have soft delete enabled.

### Remediation action:

To enable soft delete on a Recovery Services Vault:
1. Go to the Azure portal: https://portal.azure.com
2. Navigate to **Recovery Services Vaults**
3. Select the vault and go to **Properties**
4. Under **Soft Delete**, ensure it is set to **Enabled**

Note: New vaults typically have soft delete enabled by default.

### Related links

* [Soft delete for Recovery Services vaults](https://learn.microsoft.com/en-us/azure/backup/backup-azure-security-feature-cloud)

<!--- Results --->
%TestResult%
