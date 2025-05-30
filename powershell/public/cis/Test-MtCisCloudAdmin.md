1.1.1 (L1) Ensure Administrative accounts are cloud-only

Administrative accounts are special privileged accounts that could have varying levels of access to data, users, and settings. Regular user accounts should never be utilized for administrative tasks and care should be taken, in the case of a hybrid environment, to keep Administrative accounts separated from on-prem accounts. Administrative accounts should not have applications assigned so that they have no access to potentially vulnerable services (EX. email, Teams, SharePoint, etc.) and only access to perform tasks as needed for administrative purposes.

#### Remediation action:

To created licensed, separate Administrative accounts for Administrative users:
1. Navigate to Microsoft 365 admin center [https://admin.microsoft.com](https://admin.microsoft.com).
2. Click to expand **Users** select **Active users**
3. Click **Add a user**.
4. Fill out the appropriate fields for Name, user, etc.
5. When prompted to assign licenses select as needed **Microsoft Entra ID P1** or
**Microsoft Entra ID P2**, then click **Next**.
6. Under the **Option settings** screen you may choose from several types of
Administrative access roles. Choose **Admin center access** followed by the
appropriate role then click **Next**.
7. Select **Finish adding**.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v 4.0.0 - Page 20](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%