// Statuses selected when a report first loads. NotRun is omitted so tests that were
// filtered out by tag (AD, Preview, LongRunning) do not crowd the default view — they
// stay in the data and remain one click away in the status filter.
export const defaultSelectedStatus = ["Passed", "Failed", "Skipped", "Investigate", "Error"]

// Every status the status filter offers.
export const allSelectableStatus = ["Passed", "Failed", "Investigate", "Skipped", "NotRun", "Error"]
