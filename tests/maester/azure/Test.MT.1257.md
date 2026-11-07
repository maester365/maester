Ensure no resource is left **unhealthy for a Microsoft Defender for Cloud recommendation**.

Defender for Cloud assesses the resources of every subscription it covers against a catalogue of recommendations and reports, per recommendation, which resources are healthy. An assessor normally reads that one recommendation at a time in the Azure portal. This check brings it into a Maester run.

It runs **once per recommendation**, following the `InstanceSource` pattern `MT.1024` introduced — never once per resource. A large estate produces thousands of assessment rows and only hundreds of recommendations, and that difference is what keeps the report readable.

A recommendation **passes** when no resource is unhealthy and **fails** when any is. The result carries the assessment key, the resource counts, the severity Defender assigns, the Defender CSPM risk level when the plan is on, a sample of up to ten unhealthy resource names, and the portal link to the full list.

Severity follows the source. Defender CSPM adds a risk level per recommendation and that is preferred when present; otherwise the recommendation's own metadata severity is used.

## When this is skipped

- **Every resource is exempt.** An exemption is a decision already recorded in the Azure portal, so the check reports it with the count and does not raise the recommendation again.
- **Nothing was evaluated either way.** When a recommendation has no healthy and no unhealthy resource, there is no outcome to judge and the result is skipped as not applicable. **No unhealthy resource over no evaluated resource is not a pass.**
- **No assessment at all.** When Defender for Cloud returns nothing for the readable subscriptions, the instance source emits nothing and the engine skips the family with `NoInstances`. A subscription with no assessment has no recommendation to comply with.

## How to remediate

Open the recommendation in **Microsoft Defender for Cloud** → **Recommendations** and either remediate the resources listed or exempt the recommendation there, so the decision is recorded in the portal rather than lost.

## Permissions

Read-only. Reader or Security Reader on the subscriptions, or on a management group above them. The query runs through Azure Resource Graph, so it covers every readable subscription in one call.

<!--- Results --->
%TestResult%
