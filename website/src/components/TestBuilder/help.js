// What the help panel of a field says beyond its one-line hint: how the engine uses the value, and what happens
// when the field is left empty. The facts are those of website/docs/writing-tests/index.mdx (the attribute table,
// License, Permission, TenantType and Cloud, Platform); change both together.
//
// `more` and `empty` are Markdown. `empty` may differ for a test shipped with Maester (`builtin`) and a custom test.

const REQUIRED = "A test shipped with Maester must have one: the unit tests fail without it.";
const UNFILTERED = "A custom test may leave it empty. The result then has no value for it, so the report and `Invoke-Maester` cannot group or filter the test by it.";

export const FIELD_HELP = {
  suite: {
    more: "The suite is the folder under `tests/` and the first part of the ID. Use **Maester** for a check the community wrote. Use a benchmark suite (CIS, CISA, ASD, DISA) only for a test that implements one requirement of that benchmark, and then also list the requirement under Framework requirements.",
    empty: "A suite is always chosen. It decides where the files go and which ID prefixes are valid.",
  },
  prefix: {
    more: "The prefix keeps your IDs apart from Maester's own and from any pack you install. Pick one that names your organization, for example `CONTOSO`, and use it for every test you write.",
    empty: "`CT` is used.",
  },
  id: {
    more: "The ID is how everything refers to the test: `-TestId` on the command line, a `TestSettings` row in `maester-config.json`, the report and the history of earlier runs. The files are named after it, `Test.<Id>.ps1` and `Test.<Id>.md`.",
    empty: "The test cannot be created. The ID and the title are the two values every test has.",
  },
  title: {
    more: "The result is named `<Id>: <Title>` in the report, the console and exports. Write it as the state you want, not as a question or an instruction, and do not add words such as Preview: the lifecycle says that.",
    empty: "The test cannot be created. The ID and the title are the two values every test has.",
  },
  functionName: {
    more: "Maester calls this function to run the test. A name of your own is useful when the function is also called by another test, for example a benchmark test that returns this test's result.",
    empty: "The function is named after the ID: `MT.1234` becomes `Test-MT1234`.",
  },
  product: {
    more: "The product is where an administrator makes the fix. The console progress and the run summary group tests by it, the report filters on it, and `Invoke-Maester -Product` selects by it.",
    empty: { builtin: REQUIRED, custom: UNFILTERED },
  },
  feature: {
    more: "The feature is the part of the product the test is about, such as Conditional Access in Entra ID. It is the second level of every filter, and `Get-MtTest -Product <key> -Feature <key>` lists the tests that already check it, which is how you find a duplicate.",
    empty: { builtin: REQUIRED, custom: UNFILTERED },
  },
  relatedProducts: {
    more: "Tick a product only when the test reads its settings too, or the fix needs it. `-Product` then finds the test under either product.",
    empty: "The test is listed under its own product only. Most tests leave this empty.",
  },
  area: {
    more: "The area is the security theme, whatever the product: an Exchange test and an Entra test about sign-in both have the area Authentication. It lets a reader see every authentication finding across products.",
    empty: { builtin: REQUIRED, custom: UNFILTERED },
  },
  resourceType: {
    more: "The resource type is what a failing result points at: the tenant as a whole, or each user, application, policy or device that is wrong. It tells the reader how many things they will have to change.",
    empty: { builtin: REQUIRED, custom: UNFILTERED },
  },
  severity: {
    more: "Severity orders the report, and `Invoke-Maester -Severity` selects by it. An Info test is left out of scores. It is the default: an organization can change it for its own tenant with a `TestSettings` row in `maester-config.json`, so rate the test for a typical tenant, not for yours.",
    empty: { builtin: REQUIRED, custom: "The result has no severity, so the report cannot order it by severity and `-Severity` does not select it." },
  },
  userImpact: {
    more: "Together with the implementation cost, this lets a reader pick the quick wins: a high severity fix that users will not notice and that takes minutes.",
    empty: { builtin: "Required, unless the severity is Info. An Info test makes no risk judgement, so it has neither value.", custom: "The result has no user impact, and the report cannot sort or filter the test by it." },
  },
  implementationCost: {
    more: "The cost is the administrator's work to apply the recommended fix: a switch to flip is Low, a project with a rollout is High. Licence cost is not part of it.",
    empty: { builtin: "Required, unless the severity is Info. An Info test makes no risk judgement, so it has neither value.", custom: "The result has no implementation cost, and the report cannot sort or filter the test by it." },
  },
  mitre: {
    more: "The report shows the techniques and their tactics on the result and in the ATT&CK view, so a reader can see which attacks an open finding leaves room for. List at most five, and prefer a sub-technique such as `T1110.003` to its parent when it fits.",
    empty: {
      builtin: "Not allowed. Either list techniques, or tick **None** to say on purpose that no technique applies, as for an inventory or licensing test. `None` is written to the attribute, so a reviewer knows it was a decision.",
      custom: "The result has no ATT&CK mapping and does not appear in the ATT&CK view.",
    },
  },
  control: {
    more: "The first reference to a framework Maester ships a file for becomes the **Benchmark** of the result, and the engine adds that requirement's own related references, so do not repeat those.",
    empty: "The test belongs to no framework. It still runs and is reported, but it is not counted in any benchmark's coverage and has no Benchmark value.",
  },
  services: {
    more: "Every service you tick must be connected. Before it calls your function, the engine checks each one. When one is missing the test is **Skipped** with reason `ServiceNotConnected`, and the message names the service to connect. Active Directory is an opt-in service: its tests are not run at all until someone connects it with `Connect-Maester -Service ActiveDirectory`.",
    empty: {
      builtin: "Not allowed. Tick the services, or tick **None** for a test that needs no connection, such as one that reads only local files.",
      custom: "No connection is checked. If the code then calls a service that is not connected, the call throws and the result is **Error** instead of Skipped.",
    },
  },
  license: {
    more: "Name service plans, not products: a product such as Microsoft 365 E5 is a bundle that changes, and the same feature ships in many bundles. Only enabled subscriptions count. In a tenant without the licence the test is **Skipped** with reason `LicenseNotFound`, and the message names what the tenant lacks, for example “This test requires Microsoft Entra ID P2 and Agent 365. The tenant does not have Agent 365.”\n\nWhen Maester cannot read the tenant's licences (no Graph connection, or no permission), the licence check is not applied and the test runs.\n\nIn the attribute each box is one element and `&` joins the plans in it, so “Entra ID P1 and Intune, or Entra ID P2” is `License = ('AAD_PREMIUM&INTUNE_A', 'AAD_PREMIUM_P2')`.",
    empty: "The test runs in every tenant, whatever it is licensed for. Leave it empty only when the setting exists in every tenant. If the feature needs a licence and you do not say so, an unlicensed tenant gets a **Failed** or **Error** result for something it cannot use.",
  },
  permission: {
    more: "In 3.0 the permissions are **recorded, not enforced**: they are written to the result so the report can say what the test needs, and Maester does not skip a test because one is missing. The identity needs every box, and any one of the alternatives inside a box.\n\nA permission is written `<Service>:<Kind>:<Name>` and `|` joins alternatives, so “User.Read.All, and Policy.Read.All or Directory.Read.All” is `Permission = ('Graph:Scope:User.Read.All', 'Graph:Scope:Policy.Read.All | Graph:Scope:Directory.Read.All')`.",
    empty: "Nothing is recorded. The test still runs, but when it cannot read its data the report cannot tell the administrator which permission to grant.",
  },
  tenantType: {
    more: "A Microsoft Entra tenant is one of two kinds:\n\n- **Workforce**: an organization's own tenant, for its employees, partners and guests. This is what most tenants are.\n- **External (Consumer)**: a Microsoft Entra External ID tenant, which holds the customer or consumer accounts of an app the organization publishes. Many workforce settings do not exist there.\n\nTick both for a test that is valid in either. Maester detects the kind of tenant and writes it to the result. By default it only records a mismatch. A run skips on it when `Environment.Enforce.TenantType` is turned on in `maester-config.json`; a test whose tenant types do not include the tenant's is then **Skipped** with reason `TenantTypeMismatch`.",
    empty: "The test is treated as **Workforce** only. It is not treated as valid in every tenant: with enforcement on, it is skipped in an External ID tenant. Tick External as well if the test applies there.",
  },
  cloud: {
    more: "Commercial is the worldwide cloud. GCC, GCC High and DoD are the United States government clouds, China is operated by 21Vianet, Bleu is the French sovereign cloud, Delos the German one and GovSG the Singapore government cloud.\n\nTick the clouds only when the feature is missing or different in some of them, for example a setting that sovereign clouds do not have. Maester detects the tenant's cloud and writes it to the result. By default a mismatch is only recorded; with `Environment.Enforce.Cloud` turned on in `maester-config.json`, the test is **Skipped** with reason `CloudMismatch` in a cloud you did not tick.",
    empty: "The test is valid in every cloud and is never skipped because of the cloud.",
  },
  platform: {
    more: "This is the operating system of the computer that runs Maester, not of the devices in the tenant. Tick Windows when the code calls a Windows-only command or module. This one is always enforced: on another operating system the test is **Skipped** with reason `PlatformMismatch`.",
    empty: "The test runs on Windows, Linux and macOS. Most tests leave this empty.",
  },
  parameters: {
    more: "A value comes from, in order: `-Parameter` on the command line, the test's row under `TestSettings` in `maester-config.json`, the shared setting the parameter is bound to under `GlobalSettings`, and last the default written in the code. The result records each value and where it came from.",
    empty: "The test has an empty `param()` block and nothing to configure. That is right for most tests.",
  },
  lifecycle: {
    more: "- **Preview**: not run unless the user asks, with `-IncludePreview`, any `-Tag`, or the exact ID in `-TestId`. Use it while a test is new and its results are still being checked on real tenants.\n- **Stable**: runs by default.\n- **Deprecated**: still runs, and the result says it is deprecated and which test replaced it.",
    empty: "The test is **Stable** and runs by default. The attribute is written only for Preview and Deprecated.",
  },
  replacedBy: {
    more: "The ID of the test that took this one's place. The result of a deprecated test points readers to it.",
    empty: "A deprecated test with no replacement is reported as deprecated, with nowhere to send the reader.",
  },
  flags: {
    more: "- **LongRunning**: the test is left out of a normal run. It runs with `-IncludeLongRunning`, with `-Tag LongRunning`, or when its exact ID is in `-TestId`. Use it for a test that takes minutes, such as one that reads every sign-in.\n- **Exclusive**: the test must not run at the same time as another. It is recorded for a future parallel scheduler and has no effect in 3.0.",
    empty: "Both are off: the test runs in every normal run, alongside the others.",
  },
  author: {
    more: "The GitHub handles of the people who first wrote the test, without the `@`. They are credited on maester.dev.",
    empty: { builtin: REQUIRED, custom: "Nobody is credited. A custom test does not need an author." },
  },
  contributor: {
    more: "People who changed the test later, in the order of their first change. Add yourself here when you fix or extend someone else's test; do not replace the author.",
    empty: "Only the authors are credited.",
  },
  tags: {
    more: "Tags are your own labels for selecting tests: `Invoke-Maester -Tag quarterly-review` runs the tests that carry it, and `-ExcludeTag` leaves them out. Giving any `-Tag` also includes Preview tests that carry it.",
    empty: "The test has no tags. It is still selected by ID, product, severity and the other attributes.",
  },
};

export function fieldHelp(id, builtin) {
  const entry = FIELD_HELP[id];
  if (!entry) return null;
  const empty = entry.empty && typeof entry.empty === "object" ? entry.empty[builtin ? "builtin" : "custom"] : entry.empty;
  return { more: entry.more, empty };
}
