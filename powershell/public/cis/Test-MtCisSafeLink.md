2.1.1 (L2) Ensure Safe Links for Office Applications is Enabled

Safe Links for Office applications extends phishing protection to documents and emails that contain hyperlinks, even after they have been delivered to a user.

#### Remediation action:

To create a Safe Links policy:

1. Navigate to Microsoft 365 admin center [https://admin.microsoft.com](https://admin.microsoft.com).
2. Under **Email & collaboration** select **Policies & rules**
3. Select **Threat policies** then **Safe Links**
4. Click on **+Create**
5. Name the policy then click **Next**
6. In Domains select all valid domains for the organization and Next
7. Ensure the following **URL & click protection settings** are defined:

**Email**
* Checked **On: Safe Links checks a list of known, malicious links when users click links in email. URLs are rewritten by default**
* Checked **Apply Safe Links to email messages sent within the organization**
* Checked **Apply real-time URL scanning for suspicious links and links that point to files**
* Checked **Wait for URL scanning to complete before delivering the message**
* Unchecked **Do not rewrite URLs, do checks via Safe Links API only**.

**Teams**
* Checked **On: Safe Links checks a list of known, malicious links when users click links in Microsoft Teams. URLs are not rewritten**.

**Office 365 Apps**
* Checked On: **Safe Links checks a list of known, malicious links when users click links in Microsoft Office apps. URLs are not rewritten**

**Click protection settings**
* Checked: **Track user clicks**
* Unchecked: **Let users click through the original URL**
* There is no recommendation for organization branding
8. Click **Next** twice and finally Submit.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 70](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%