Checks JSON files that you supply for drift from a baseline.

Create a `drift` folder (or pass `-DriftRoot` to `Invoke-Maester`) with one subfolder per drift check. Each subfolder holds a `baseline.json` (the expected configuration), a `current.json` (the actual configuration) and an optional `settings.json` whose `ExcludeProperties` lists properties to skip.

Four results are created per folder, with the folder name made safe for a test ID:

- `MT.1060.<folder>.1`: the baseline file exists and is valid JSON.
- `MT.1060.<folder>.2`: the current file exists and is valid JSON.
- `MT.1060.<folder>.3`: the current file has no properties missing from the baseline.
- `MT.1060.<folder>.4`: every value in the current file matches the baseline.

In Maester 2.x these results were named `MT1060.<folder>.<n>`. The `MT1060`, `MT1060.<n>`, `MT1060.<folder>` and `MT1060.<folder>.<n>` tags are kept.

#### Remediation action

Update the configuration, or the baseline, so that the two files match.

<!--- Results --->
%TestResult%
