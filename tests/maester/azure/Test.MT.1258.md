Ensure Microsoft Defender for Cloud reports **no active attack path**.

Defender CSPM correlates the weaknesses of an estate into attack paths: a chain that starts at something an attacker can reach and ends at something worth reaching. An individual recommendation rates each weakness on its own; the **path** is what makes the combination matter. A virtual machine with a known vulnerability is one finding, a storage account holding a connection string is another, and the path that joins them is the thing an attacker actually walks.

This check runs **once per attack path** Defender for Cloud reports, and **fails** for each one, because an attack path is an active route rather than a configuration opinion.

The result names the entry point's resource type, the target, the risk factors Defender combined and the MITRE tactics the path covers.

Severity follows the source: the risk level Defender assigns to the path.

## On the fields

Measured against a live Defender CSPM subscription rather than assumed:

- `properties.attackPathType` is a **GUID** and `properties.displayName` is a sentence. The engine requires an instance ID matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`, so the GUID identifies the path type and the sentence is the title. Grouping by the GUID is also what *"one result per attack path type"* means.
- `properties.entryPoint` carries `entityInternalId`, `entityType` and `dataSource`, and **no entity name**, so the entry point is reported by its resource type.
- `properties.target` does carry `entityName` as well as `entityType`, so the target is named.
- `properties.riskFactors` and `properties.mITRETacticsAndTechniques.tactics` are arrays, and Azure Resource Graph has no `mv-apply`, so they travel as JSON text and are parsed in the helper.

## When this is skipped

- **Defender CSPM is not enabled** on any readable subscription. No attack path was ever computed, so an empty result says nothing about the estate. The family reports that instead of a pass, read from the `CloudPosture` pricing tier.
- **The plan is on and no path exists.** The instance source emits nothing and the engine skips the family with `NoInstances`. That is genuinely good news, and it is reported as "nothing to judge" rather than as a passing check, because this family has one result per path and no path to attach a pass to.

## How to remediate

Break the path rather than every weakness on it. Removing the entry point's exposure, or the credential or permission that allows the step to the target, closes the whole route. Defender for Cloud lists the recommendations that make up each path in the Azure portal, under **Attack path analysis**.

## Permissions

Read-only. Reader or Security Reader on the subscriptions, plus the **Defender CSPM** plan enabled.

<!--- Results --->
%TestResult%
