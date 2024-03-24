# <img src="https://maester.dev/img/logo.svg" alt="Maester logo" height="40" width="40" /> Maester Test Results

This is a summary of the test results from the Maester test run.

**Tenant:** %TenantName%

**Tenant ID:** %TenandId%

**Date:** %TestDate%

| <img src="https://maester.dev/img/logo.svg" alt="Maester logo" height="18" width="18" /> <br/> Total Tests | <img src="https://maester.dev/img/test-result/icon-passed.png" alt="Passed icon" height="18" /><br/>Passed  | <img src="https://maester.dev/img/test-result/icon-fail.png" alt="Failed icon" height="18" /><br/> Failed | <img src="https://maester.dev/img/test-result/icon-notrun.png" alt="Not run icon" height="18" /><br/> Not Run |
|:-:|:-:|:-:|:-:|
|**%TotalCount%**|**%PassedCount%**|**%FailedCount%**|**%NotRunCount%**|


## Test status
```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'pie1': '#10b981', 'pie2': '#f43f5d', 'pie3': '#6b7280'}}}%%
pie showData
    "Passed" : %PassedCount%
    "Failed" : %FailedCount%
```

## Test summary

%TestSummary%

# Test details

%TestDetails%