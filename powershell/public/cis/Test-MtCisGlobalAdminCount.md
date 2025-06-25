1.1.3 (L1) Ensure that between two and four global admins are designated

More than one global administrator should be designated so a single admin can be monitored and to provide redundancy should a single admin leave an organization. Additionally, there should be no more than four global admins set for any tenant. Ideally global administrators will have no licenses assigned to them.

#### Remediation action:

To correct the number of global tenant administrators:
1. Navigate to Microsoft 365 admin center [https://admin.microsoft.com](https://admin.microsoft.com).
2. Select **Users** > **Active Users**.
3. In the Search field enter the name of the user to be made a Global Administrator.
4. To create a new Global Admin:
 1. Select the user's name.
 2. A window will appear to the right.
 3. Select **Manage roles**.
 4. Select **Admin center access**.
 5. Check **Global Administrator**.
 6. Click Save changes.

To remove Global Admins:
1. Select **User**.
2. Under Roles select **Manage roles**.
3. De-Select the appropriate role.
4. Click **Save changes**.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 28](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%