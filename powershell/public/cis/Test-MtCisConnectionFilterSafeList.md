2.1.13 (L1) Ensure the connection filter safe list is off

**Rationale:**
Without additional verification like mail flow rules, email from sources in the IP Allow List skips spam filtering and sender authentication (SPF, DKIM, DMARC) checks. This method creates a high risk of attackers successfully delivering email to the Inbox that would otherwise be filtered. Messages that are determined to be malware or high confidence phishing are filtered. The safe list is managed dynamically by Microsoft, and administrators do not have visibility into which sender are included. Incoming messages from email servers on the safe list bypass spam filtering.

#### Remediation action:

To remove IPs from the allow list:
1. Navigate to Microsoft 365 Defender [https://security.microsoft.com](https://security.microsoft.com).
2. Click to expand **Email & collaboration** select **Policies & rules** > **Threat policies**.
3. Under policies select **Anti-spam**.
4. Click on the **Connection filter policy (Default)**.
5. Ensure Safe list is Off.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 116](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%