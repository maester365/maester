# Microsoft Zero Trust Assessment pack

The [Zero Trust Assessment](https://aka.ms/zerotrust/assessment) is Microsoft's free tool that checks a tenant
against Microsoft's Zero Trust guidance, across identity, devices, network, data, AI and security operations, and
says how to fix what it finds.
[Try the demo report](https://aka.ms/zerotrust/assessment/demo) to see what it covers.

This pack runs the assessment from Maester and shows each of its results in the Maester report, next to Maester's
own checks. It ships with Maester and runs only when you ask for it.

Each result is one row, `ZTA.<assessment test ID>` (for example `ZTA.21770`), with the assessment's title, risk
level (as the severity), description, remediation steps and findings. Results are tagged `ZeroTrust` and
`ZeroTrust.<pillar>` (`ZeroTrust.Identity`, `ZeroTrust.Devices` and so on).

## Report an issue with a test

Microsoft writes and maintains the assessment's tests. If a test's result, text or remediation looks wrong, raise
it in [microsoft/zerotrustassessment](https://github.com/microsoft/zerotrustassessment/issues). Problems with
running the pack from Maester go to [maester365/maester](https://github.com/maester365/maester/issues).

## Run it

Install the assessment's module once, connect Maester to the tenant, then name the pack:

```powershell
Install-Module ZeroTrustAssessment -Scope CurrentUser
Connect-Maester
Invoke-Maester -Pack ZTA -SkipBuiltIn    # only the Zero Trust Assessment
Invoke-Maester -Pack ZTA                 # Maester's tests and the assessment
```

The assessment runs in its own PowerShell process, so Maester signs in there for you. After an interactive
`Connect-Maester` you sign in a second time, in the browser. Without a browser, for example over SSH, set
`ZeroTrustAssessment.Connect` to `{ "UseDeviceCode": true }` in `maester-config.json`.

### Sign in as a service principal

In a pipeline, or anywhere nobody can sign in, connect Maester to Graph app-only with a certificate. The
assessment uses the same app and certificate, found by its thumbprint in the certificate store. A client secret, a
managed identity or workload identity federation is enough for Maester's own tests, but the assessment signs in
app-only only with a certificate.

```powershell
Import-Module ZeroTrustAssessment
Get-ZtGraphScope    # the Graph application permissions to give the app

Connect-MgGraph -ClientId <app id> -TenantId <tenant id> -CertificateThumbprint <thumbprint> -NoWelcome
Invoke-Maester -Pack ZTA -NonInteractive
```

To leave out the assessment's Azure, Exchange Online, Security & Compliance and SharePoint tests, which need extra
roles for the app, set `ZeroTrustAssessment.Connect` to `{ "Service": ["Graph"] }`.

### Read a report you already have

Run the assessment as its own step, then point Maester at the report it wrote:

```powershell
Connect-ZtAssessment
Invoke-ZtAssessment -Path ./zt -NoBrowser
```

```json
{ "GlobalSettings": { "ZeroTrustAssessment.ReportPath": "./zt" } }
```

Then, in a new PowerShell session, run `Connect-Maester` and `Invoke-Maester -Pack ZTA`.

The assessment can take an hour or more on a large tenant. All its settings, a GitHub Actions workflow and how its
results map are on [maester.dev/docs/next/packs/zero-trust-assessment](https://maester.dev/docs/next/packs/zero-trust-assessment).

The Zero Trust Assessment is © Microsoft Corporation and published under the
[MIT licence](https://github.com/microsoft/zerotrustassessment/blob/main/LICENSE). This pack does not include
its code: it runs the module you install, or reads the report it wrote.
