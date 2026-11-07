Ensure every Azure subscription **meets the Microsoft Defender for Cloud secure score target**.

Defender for Cloud scores every subscription it covers against its recommendations and expresses the result as a percentage of the maximum achievable score. An assessor reads that number first and the individual recommendations afterwards. This check brings the number into a Maester run, **one result per subscription**, and carries the state of the regulatory compliance standards assigned to that subscription in the same result.

A subscription **passes** when its secure score reaches the target and **fails** below it. The target is a business decision rather than a vendor rule, so it is a parameter: **80%** by default.

```powershell
# Raise the bar for one subscription in the Maester config
TestSettings = @(
    @{ Id = 'MT.1266.00000000-0000-0000-0000-000000000000'; Parameters = @{ MinimumScorePercentage = 90 } }
)
```

The percentage is computed from the current and maximum score rather than read from `properties.score.percentage`, whose unit the Azure samples present two different ways — the secure score page divides current by max itself while the Resource Graph sample projects the property directly. Dividing removes the ambiguity.

## Regulatory compliance

The standards assigned to the subscription are reported as a **summary table**: state, and how many controls passed, failed, were skipped or are unsupported. They are deliberately not separate results. The controls behind those numbers are the Defender for Cloud recommendations that `MT.1257` already reports one by one, and raising them again here would count the same finding twice.

The Microsoft cloud security benchmark is assigned by default, so an empty list usually means it was removed rather than that nothing applies. Other standards, such as CIS Azure, need Defender CSPM.

## When this is skipped

- **The maximum score is zero.** Defender for Cloud produced a score row for the subscription but assessed nothing in it, so there is no percentage to compare. The subscription is still reported, with that reason: **no score is not a score of zero, and it is not a pass.**
- **No score at all.** When Defender for Cloud returns no secure score for the readable subscriptions, the instance source emits nothing and the engine skips the family with `NoInstances`. A tenant with no scored subscription has no score to meet.

## How to remediate

Open **Microsoft Defender for Cloud** → **Secure score**, which lists the security controls by how many points each would add. The points are weighted, so the controls at the top of that list move the number furthest. `MT.1257` reports the individual recommendations behind each control.

## Permissions

Read-only. Reader or Security Reader on the subscriptions, or on a management group above them. The queries run through Azure Resource Graph, so they cover every readable subscription in three calls regardless of how many subscriptions there are.

<!--- Results --->
%TestResult%
