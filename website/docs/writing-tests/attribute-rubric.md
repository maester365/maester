---
title: Attribute rubric
sidebar_position: 2
description: How to choose the classification, priority and mapping attributes of a Maester test, and how those choices are checked.
---

# Attribute rubric

Every test shipped with Maester declares what it is about, how urgent a failure is and which attack techniques
it addresses. This page is the rule book for those values. Unit tests check what can be checked mechanically, and
a review step checks the judgement calls against this page. A custom test may use the same attributes; the rules
apply to it only if you want them to.

| Question | Attributes | Required for built-in tests |
| --- | --- | --- |
| What is it about? | `Product`, `RelatedProduct`, `Feature`, `Area`, `ResourceType` | All except `RelatedProduct` |
| What do I fix first? | `Severity`, `UserImpact`, `ImplementationCost` | `Severity` always. The other two unless `Severity` is `Info` |
| What does it map to? | `Mitre`, `Control` | `Mitre` (technique IDs or `None`) |
| Is it current? | `Lifecycle`, `ReplacedBy` | No. `Lifecycle` defaults to `Stable` |

The allowed keys for `Product`, `Feature`, `Area` and `ResourceType` are in
[`powershell/assets/MaesterTaxonomy.psd1`](https://github.com/maester365/maester/blob/main/powershell/assets/MaesterTaxonomy.psd1).
Add a key there in the same pull request as the first test that needs it.

## Rate the test, not your tenant

Rate every value for a typical organization that fails the test, using the fix the test's own Markdown file
recommends. Do not rate for the best case, the worst case or one tenant you know. When two values fit, choose the
lower one for `Severity`, `UserImpact` and `ImplementationCost`. A reader should be able to see the reason for
each value in the test's description and remediation text.

## Product

The product where the fix is made. One value.

- Use the product whose admin surface holds the setting, not every product the test reads from.
- Tests in a product folder (`tests/maester/entra`, `tests/cisa/exchange`) use that folder's product.
- A product the test only reads from, or a licence it needs, is not a second product. `Service` and `License`
  already say that.

## RelatedProduct

Other products the test also checks or depends on. Optional list, never the same key as `Product`.

- Add one when an admin of that product would expect to find the test under it. An Exchange Online test about an
  anti-phishing policy that is managed in the Defender portal has `RelatedProduct = 'defender'`.
- Add one when the fix is made in that product's portal although the test lives in another product's folder.
- Do not add a product only because its API is called.

## Feature

The part of the product the test is about. One key from the product's `Features` list.

- Choose the feature whose settings page or object type the remediation sends the admin to.
- When a test spans two features, choose the one that fails most directly. A Conditional Access policy that
  requires a compliant device is `conditional-access`, not `devices`.
- Tests that check the same thing get the same feature, whatever folder or suite they are in.
- A feature that would hold one test only is usually too narrow. Prefer an existing feature.

## Area

The security theme, whatever the product. One key.

| Key | Use it for |
| --- | --- |
| `authentication` | How an identity proves who it is: MFA, authentication methods, passwords, legacy protocols, Kerberos and NTLM hardening, session and token lifetime. |
| `privileged-access` | Administrative roles and accounts: who holds them, just-in-time elevation, emergency access, admin tiering, delegated admin rights. |
| `access-control` | Who may reach which resource under which conditions: device, location and risk conditions, permissions on objects, user defaults. |
| `applications` | App registrations, service principals and their credentials, consent and API permissions, OAuth apps, add-ins, connectors. |
| `external-access` | Guests, cross-tenant access, federation and trusts, external sharing and external communication. |
| `devices` | Device compliance, enrollment and configuration, endpoint protection, device identity. |
| `email-protection` | Anti-phishing, anti-spam and anti-malware, Safe Links and Safe Attachments, SPF, DKIM and DMARC, mail flow rules, meeting and messaging protections. |
| `data-protection` | Data loss prevention, sensitivity labels, encryption, retention, backup. |
| `logging-and-detection` | Audit logs, diagnostic settings, alert policies, sensors and the health of detection tooling. |
| `identity-lifecycle` | Stale and dormant accounts, ownership, access reviews, entitlement management, group membership hygiene. |
| `infrastructure` | The directory and platform itself: domain controllers, DNS, replication, sites, schema, Group Policy health, protocol hardening, subscriptions, tenant-wide platform settings. |
| `engineering-systems` | DevOps organizations, repositories, pipelines, build identities, the software supply chain. |
| `ai` | AI agents and copilots: who can use and share them, how they authenticate, what data and tools they reach. |

When more than one area fits, choose by what the control is for, in this order:

1. It protects administrators or admin rights: `privileged-access`.
2. It decides how sign-in is proven: `authentication`.
3. It is about an application, service principal or agent as the subject: `applications`, or `ai` for agents.
4. It is about people or data outside the organization: `external-access`.
5. Otherwise the area that names the mechanism: `access-control`, `devices`, `email-protection`,
   `data-protection`, `logging-and-detection`, `identity-lifecycle`, `engineering-systems`, `infrastructure`.

A product never decides the area on its own. An Azure DevOps test about who is a Project Collection Administrator
is `privileged-access`, not `engineering-systems`.

Inventory and health tests with no security theme of their own are `infrastructure`. When no area fits, choose
the closest and say so in the pull request, so the list can be reviewed.

## ResourceType

What a failing result points at. One key.

- `Tenant` when the test evaluates one tenant-, organization-, forest- or domain-wide setting. The result is
  about the environment.
- `Tenant` when the test checks that at least one policy of a kind exists, even when it lists the policies that
  satisfy it. A failing result has nothing to list.
- `Tenant` when the test evaluates the single default or global policy of a kind, because there is one of it and
  it applies to everyone.
- Otherwise the kind of object a failing result lists or counts: `User`, `Application`, `Device`,
  `ConditionalAccessPolicy`, `GroupPolicy` and so on. A test that evaluates every policy and lists the ones that
  fail uses the policy type.
- A test that counts objects for review (an inventory test) uses the type it counts. When no key names that kind
  of object and it is a one-off, use `Tenant`.
- A family test, which yields one result per instance, uses the type of the instance.

## Severity

The risk to the organization while the test fails. Not the effort to fix it and not the disruption of fixing it.

| Value | A failing result means |
| --- | --- |
| `Critical` | An attacker with no special position can take over the tenant, the domain or a privileged identity, or a secret is already exposed. Directly exploitable and wide in reach. |
| `High` | A primary control is missing or weakened for many users or for privileged identities, and common techniques such as phishing, password spray or consent phishing are enough to use it. |
| `Medium` | A defence-in-depth control is missing, or the exposure is limited to a few objects or one workload, or using it needs another weakness first. |
| `Low` | Hardening or hygiene with a small security effect on its own. |
| `Info` | The test reports a fact for review and makes no risk judgement. Info tests are left out of scores. |

Decide in this order:

1. **Reach.** Privileged identities or the whole tenant move the value up. A single workload or a few objects
   move it down.
2. **Directness.** Usable from the internet or by any signed-in user moves it up. Needing an earlier compromise
   moves it down.
3. **Role of the control.** The main control for a threat rates higher than a second layer behind another control.

`Critical` is rare. If the description cannot say in one sentence how an attacker gets from the failing state to
admin rights or exposed secrets, the value is `High` or lower. A benchmark's own wording does not set the value:
a SHALL policy can be `Medium`.

Four cases come up often:

- **A test that passes whenever its data can be read** is `Info`, whatever the data is about. If the fact
  deserves a severity, the test should fail on it.
- **A failure that is only an outage or untidiness**, such as replication health, an expiring token or an unused
  object, is `Low`. It is `Medium` or higher only when the outage switches off a security control, and then it is
  rated as the loss of that control.
- **Alerts and notifications** are a second layer behind the control they watch, so they are `Medium` at most.
- **The same check in two suites** gets the same value in both.

Anchors from existing tests:

| Test | Value | Why |
| --- | --- | --- |
| No Group Policy object contains a `cpassword` | `Critical` | Any domain user can read and decrypt the stored password. |
| No domain admin account has a service principal name | `Critical` | Any domain user can request a ticket and crack an admin password offline. |
| Legacy authentication is blocked | `High` | Password spray bypasses MFA for every user. |
| Users cannot register applications | `Medium` | Needs a signed-in user and a further step to cause harm. |
| MailTips are enabled for end users | `Low` | A small aid against mis-sent mail. |
| Disabled user count should be retrievable | `Info` | Inventory for review. |

## UserImpact

How much the recommended fix disrupts end users. Administrators and the owners of applications are not end
users here. Developers are the end users of Azure DevOps and GitHub.

| Value | Applying the fix |
| --- | --- |
| `Low` | End users notice nothing, or only administrators are affected. |
| `Medium` | Some users change how they work or meet a new prompt: a group loses a capability, users register a method once, a legacy client stops working for a subset. |
| `High` | Most users change a daily habit, or a mistake locks people out or stops mail or an app for many. Needs communication and a staged rollout. |

Omit `UserImpact` when `Severity` is `Info`.

## ImplementationCost

How much administrator work the recommended fix takes.

| Value | The fix is |
| --- | --- |
| `Low` | One setting or one policy in one portal. Under an hour, with no dependency on another team, a licence purchase or a rollout. |
| `Medium` | Several steps: a policy that needs exclusions and a pilot, clean-up of a handful of objects, coordination with one other team. Hours to a few days. |
| `High` | A project: new licences, infrastructure or process, a migration of users or apps, or clean-up across many objects. Weeks or more. |

Clean-up that one administrator can finish alone in a sitting is `Low`. Clean-up that needs the owner of each
object is `Medium`. Turning on a plan that is billed by use is `Medium`: the click is easy, the budget approval is
not. Count the work of the fix, including exclusions and rollout, but not the time to decide.

Omit `ImplementationCost` when `Severity` is `Info`.

## Mitre

The MITRE ATT&CK techniques that the checked control prevents or detects. A list of technique IDs, or `None`.

- IDs only, in the form `T1110` or `T1110.003`. Tactic names are looked up from the pinned ATT&CK release
  (`powershell/assets/MaesterAttackTechniques.json`) and are never typed.
- Use a sub-technique when the control addresses only that sub-technique. When three or more sub-techniques of
  one technique apply, list the technique instead. Do not list a technique together with one of its own
  sub-techniques.
- List a technique only if the test's description explains, or plainly implies, how the control stops or reveals
  it. At most five.
- A test that implements a benchmark which publishes a mapping, such as CISA SCuBA, starts from that mapping and
  then applies these rules. An ID the pinned release has retired is replaced by its successor in that release,
  found by name.
- The description means the comment-based help and the Markdown file together.
- Use `None` for a test with no attacker behaviour behind it, such as replication health or an inventory count.
  An inventory test lists a technique only when the fact it reports is itself the precondition of that technique,
  such as accounts that do not require Kerberos pre-authentication.
- A retired or unknown ID fails the unit tests.

## Control

References to framework controls the test supports, written `<framework-key>:<control-id>`, for example
`nist-800-53-r5:IA-2(1)`. Built-in tests do not use `Control`: the benchmark a suite implements is declared in
its `suite.json`, and other mappings live in framework files. Use `Control` in a custom test or a pack.

A reference says the test supports the control. It never says the organization complies with it.

## Lifecycle and ReplacedBy

- `Preview`: new and still changing. Not run unless previews are included.
- `Stable`: the default.
- `Deprecated`: kept so history stays readable. Give `ReplacedBy` when another test took its place.

## Tag

`Tag` holds labels the owner of a test folder finds useful. It is not part of Maester's taxonomy.

- Built-in tests do not carry tags for product, feature, area, suite, benchmark, licence, severity or their own ID.
  Each of those has an attribute or is derived.
- A custom test may tag freely.

## How the rubric is enforced

1. **Unit tests** (`powershell/tests/general/NativeTestAttributes.Tests.ps1`) fail when a built-in test misses a
   required attribute, uses a key that is not in the taxonomy, pairs a feature with the wrong product, lists a
   retired ATT&CK technique or carries a taxonomy tag.
2. **Attribute review** runs on every pull request that adds a test or changes one of these attributes. A
   reviewer model reads the test, its Markdown file and this page, and fails the check when a value does not fit
   the rubric, with the value it expected and the reason. A maintainer can overrule it.
3. **Reviewers**, human or agent, apply the same page. See `AGENTS.md`.
