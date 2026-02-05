5.1.5.2 (L1) Ensure the admin consent workflow is enabled

**Rationale:**
The admin consent workflow (Preview) gives admins a secure way to grant access to applications that require admin approval. When a user tries to access an application but is unable to provide consent, they can send a request for admin approval. The request is sent via email to admins who have been designated as reviewers. A reviewer acts on the request, and the user is notified of the action.

#### Remediation action:

1. Navigate to Microsoft Entra ID admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Under **Entra ID** select **Enterprise apps**
3. Under **Security** select **Consent and permissions**
4. Under **Manage** select **Admin consent settings**
5. Set **Users can request admin consent to apps they are unable to consent to** to **Yes**
6. Click Save.

#### Related links

* [Microsoft 365 Entra Admin Center](https://entra.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 187](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%