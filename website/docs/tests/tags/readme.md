---
id: overview
title: Tags Overview
sidebar_label: 🏷️ Tags
description: Overview of the tags used to identify and group related tests.
---
## Tags Overview

Tags are used by Maester to identify and group related tests. They can also be used to select specific tests to run or exclude during test execution. This makes them very useful, but they can also get in the way if too many tags are created. Our goal is to minimize the "signal to noise" ratio when it comes to tags by focusing on a few key areas:

- **Test Suites**: We use standardized tag categories for test suites that align with well-known benchmarks and baselines. This helps users quickly identify tests that align with these widely recognized standards or with Maester's own suite of tests:
  - **CIS Benchmarks**: Tags prefixed with CIS (e.g., CIS.M365.1.1, CIS.Azure.3.2)
  - **CISA & Microsoft Baseline**: Tags prefixed with CISA or MS (e.g., CISA.M365.Baseline, MS.Azure.Baseline)
  - **EIDSCA**: Tags prefixed with EIDSCA (e.g., EIDSCA.EntraID.2.1)
  - **ORCA**: Tags prefixed with ORCA (e.g., ORCA.Exchange.1.1)
  - **Maester**: Tags prefixed with Maester or MT (e.g., MT.1001, MT.1024)

- **Product Areas**: Tags related to specific products and services that are being tested:
  - Azure
  - Defender XDR
  - Entra ID
  - Exchange
  - Microsoft 365
  - SharePoint
  - Teams

- **Practices or Capabilities**: Tags that denote specific security practices or capabilities within the security domain, such as:
  - Authentication (May include related topics such as MFA, SSPR, etc.)
  - Conditional Access (CA)
  - Data Loss Prevention (DLP)
  - Extended Security Posture Management (XSPM)
  - Hybrid Identity
  - Privileged Access Management (PAM)
  - Privileged Identity Management (PIM)

### Recommendations for Tag Usage

Less is more! When creating or assigning tags to tests, consider the following best practices:

1. Assign one `Test Suite` tag per test to ensure clarity on which benchmark or baseline the test aligns with. This tag will usually go in the Describe block of a Pester test file.
2. Assign a `Product Area` tag to indicate which products or services the test is most relevant to. Limit these to 1-3 tags per test to avoid over-tagging.
3. Use `Practice` or `Capability` tags sparingly and only when they add significant value in categorizing the test. Avoid creating overly specific tags that may only apply to a single test.

## Tags Used

The tables below list every tag discovered via Get-MtTestInventory.

### CIS

| Tag | Count |
| :--- | ---: |
| CIS | 25 |
| CIS E3 | 16 |
| CIS E3 Level 1 | 15 |
| CIS E3 Level 2 | 4 |
| CIS E5 | 6 |
| CIS E5 Level 1 | 2 |
| CIS E5 Level 2 | 4 |
| CIS M365 v5.0.0 | 25 |
| L1 | 15 |
| L2 | 7 |

**Individual tags**: CIS.M365.1.1.1, CIS.M365.1.1.3, CIS.M365.1.2.1, CIS.M365.1.2.2, CIS.M365.1.3.1, CIS.M365.1.3.3, CIS.M365.1.3.6, CIS.M365.2.1.1, CIS.M365.2.1.11, CIS.M365.2.1.12, CIS.M365.2.1.13, CIS.M365.2.1.2, CIS.M365.2.1.3, CIS.M365.2.1.4, CIS.M365.2.1.5, CIS.M365.2.1.6, CIS.M365.2.1.7, CIS.M365.2.1.9, CIS.M365.2.4.4, CIS.M365.3.1.1, CIS.M365.8.1.1, CIS.M365.8.2.2, CIS.M365.8.4.1, CIS.M365.8.5.3, CIS.M365.8.6.1

### CISA

| Tag | Count |
| :--- | ---: |
| CISA | 73 |
| MS.AAD | 30 |
| MS.EXO | 41 |
| MS.SHAREPOINT | 2 |

**Individual tags**: CISA.MS.AAD.1.1, CISA.MS.AAD.2.1, CISA.MS.AAD.2.2, CISA.MS.AAD.2.3, CISA.MS.AAD.3.1, CISA.MS.AAD.3.2, CISA.MS.AAD.3.3, CISA.MS.AAD.3.4, CISA.MS.AAD.3.5, CISA.MS.AAD.3.6, CISA.MS.AAD.3.7, CISA.MS.AAD.3.8, CISA.MS.AAD.4.1, CISA.MS.AAD.5.1, CISA.MS.AAD.5.2, CISA.MS.AAD.5.3, CISA.MS.AAD.5.4, CISA.MS.AAD.6.1, CISA.MS.AAD.7.1, CISA.MS.AAD.7.2, CISA.MS.AAD.7.3, CISA.MS.AAD.7.4, CISA.MS.AAD.7.5, CISA.MS.AAD.7.6, CISA.MS.AAD.7.7, CISA.MS.AAD.7.8, CISA.MS.AAD.7.9, CISA.MS.AAD.8.1, CISA.MS.AAD.8.2, CISA.MS.AAD.8.3, CISA.MS.EXO.1.1, CISA.MS.EXO.10.1, CISA.MS.EXO.10.2, CISA.MS.EXO.10.3, CISA.MS.EXO.11.1, CISA.MS.EXO.11.2, CISA.MS.EXO.11.3, CISA.MS.EXO.12.1, CISA.MS.EXO.12.2, CISA.MS.EXO.13.1, CISA.MS.EXO.14.1, CISA.MS.EXO.14.2, CISA.MS.EXO.14.3, CISA.MS.EXO.14.4, CISA.MS.EXO.15.1, CISA.MS.EXO.15.2, CISA.MS.EXO.15.3, CISA.MS.EXO.16.1, CISA.MS.EXO.16.2, CISA.MS.EXO.17.1, CISA.MS.EXO.17.2, CISA.MS.EXO.17.3, CISA.MS.EXO.2.1, CISA.MS.EXO.2.2, CISA.MS.EXO.3.1, CISA.MS.EXO.4.1, CISA.MS.EXO.4.2, CISA.MS.EXO.4.3, CISA.MS.EXO.5.1, CISA.MS.EXO.6.1, CISA.MS.EXO.6.2, CISA.MS.EXO.7.1, CISA.MS.EXO.8.1, CISA.MS.EXO.8.2, CISA.MS.EXO.8.3, CISA.MS.EXO.8.4, CISA.MS.EXO.9.1, CISA.MS.EXO.9.2, CISA.MS.EXO.9.3, CISA.MS.EXO.9.4, CISA.MS.EXO.9.5, CISA.MS.SHAREPOINT.1.1, CISA.MS.SHAREPOINT.1.3, MS.AAD.1.1, MS.AAD.2.1, MS.AAD.2.2, MS.AAD.2.3, MS.AAD.3.1, MS.AAD.3.2, MS.AAD.3.3, MS.AAD.3.4, MS.AAD.3.5, MS.AAD.3.6, MS.AAD.3.7, MS.AAD.3.8, MS.AAD.4.1, MS.AAD.5.1, MS.AAD.5.2, MS.AAD.5.3, MS.AAD.5.4, MS.AAD.6.1, MS.AAD.7.1, MS.AAD.7.2, MS.AAD.7.3, MS.AAD.7.4, MS.AAD.7.5, MS.AAD.7.6, MS.AAD.7.7, MS.AAD.7.8, MS.AAD.7.9, MS.AAD.8.1, MS.AAD.8.2, MS.AAD.8.3, MS.EXO.1.1, MS.EXO.10.1, MS.EXO.10.2, MS.EXO.10.3, MS.EXO.11.1, MS.EXO.11.2, MS.EXO.11.3, MS.EXO.12.1, MS.EXO.12.2, MS.EXO.13.1, MS.EXO.14.1, MS.EXO.14.2, MS.EXO.14.3, MS.EXO.14.4, MS.EXO.15.1, MS.EXO.15.2, MS.EXO.15.3, MS.EXO.16.1, MS.EXO.16.2, MS.EXO.17.1, MS.EXO.17.2, MS.EXO.17.3, MS.EXO.2.1, MS.EXO.2.2, MS.EXO.3.1, MS.EXO.4.1, MS.EXO.4.2, MS.EXO.4.3, MS.EXO.5.1, MS.EXO.6.1, MS.EXO.6.2, MS.EXO.7.1, MS.EXO.8.1, MS.EXO.8.2, MS.EXO.8.3, MS.EXO.8.4, MS.EXO.9.1, MS.EXO.9.2, MS.EXO.9.3, MS.EXO.9.4, MS.EXO.9.5, MS.SHAREPOINT.1.1, MS.SHAREPOINT.1.3

### EIDSCA

| Tag | Count |
| :--- | ---: |
| EIDSCA | 44 |

**Individual tags**: EIDSCA.AF01, EIDSCA.AF02, EIDSCA.AF03, EIDSCA.AF04, EIDSCA.AF05, EIDSCA.AF06, EIDSCA.AG01, EIDSCA.AG02, EIDSCA.AG03, EIDSCA.AM01, EIDSCA.AM02, EIDSCA.AM03, EIDSCA.AM04, EIDSCA.AM06, EIDSCA.AM07, EIDSCA.AM09, EIDSCA.AM10, EIDSCA.AP01, EIDSCA.AP04, EIDSCA.AP05, EIDSCA.AP06, EIDSCA.AP07, EIDSCA.AP08, EIDSCA.AP09, EIDSCA.AP10, EIDSCA.AP14, EIDSCA.AS04, EIDSCA.AT01, EIDSCA.AT02, EIDSCA.AV01, EIDSCA.CP01, EIDSCA.CP03, EIDSCA.CP04, EIDSCA.CR01, EIDSCA.CR02, EIDSCA.CR03, EIDSCA.CR04, EIDSCA.PR01, EIDSCA.PR02, EIDSCA.PR03, EIDSCA.PR05, EIDSCA.PR06, EIDSCA.ST08, EIDSCA.ST09

### ORCA

| Tag | Count |
| :--- | ---: |
| ORCA | 67 |

**Individual tags**: ORCA.100, ORCA.101, ORCA.102, ORCA.103, ORCA.104, ORCA.105, ORCA.106, ORCA.107, ORCA.108, ORCA.108.1, ORCA.109, ORCA.110, ORCA.111, ORCA.112, ORCA.113, ORCA.114, ORCA.115, ORCA.116, ORCA.118.1, ORCA.118.2, ORCA.118.3, ORCA.118.4, ORCA.119, ORCA.120.1, ORCA.120.2, ORCA.120.3, ORCA.121, ORCA.123, ORCA.124, ORCA.139, ORCA.140, ORCA.141, ORCA.142, ORCA.143, ORCA.156, ORCA.158, ORCA.179, ORCA.180, ORCA.189, ORCA.189.2, ORCA.205, ORCA.220, ORCA.221, ORCA.222, ORCA.223, ORCA.224, ORCA.225, ORCA.226, ORCA.227, ORCA.228, ORCA.229, ORCA.230, ORCA.231, ORCA.232, ORCA.233, ORCA.233.1, ORCA.234, ORCA.235, ORCA.236, ORCA.237, ORCA.238, ORCA.239, ORCA.240, ORCA.241, ORCA.242, ORCA.243, ORCA.244

### Maester

| Tag | Count |
| :--- | ---: |
| Maester | 70 |
| Maester/Entra | 61 |
| Maester/Exchange | 9 |
| Maester/Intune | 15 |
| Maester/Teams | 6 |
| MT.1033 | 5 |

**Individual tags**: MT.1001, MT.1002, MT.1003, MT.1004, MT.1005, MT.1006, MT.1007, MT.1008, MT.1009, MT.1010, MT.1011, MT.1012, MT.1013, MT.1014, MT.1015, MT.1016, MT.1017, MT.1018, MT.1019, MT.1020, MT.1021, MT.1022, MT.1023, MT.1024, MT.1025, MT.1026, MT.1027, MT.1028, MT.1029, MT.1030, MT.1031, MT.1032, MT.1035, MT.1036, MT.1037, MT.1038, MT.1039, MT.1040, MT.1041, MT.1042, MT.1043, MT.1044, MT.1045, MT.1046, MT.1047, MT.1048, MT.1049, MT.1050, MT.1051, MT.1052, MT.1053, MT.1054, MT.1055, MT.1056, MT.1057, MT.1058, MT.1059, MT.1061, MT.1062, MT.1063, MT.1064, MT.1065, MT.1066, MT.1067, MT.1068, MT.1069, MT.1070, MT.1071, MT.1072, MT.1073, MT.1074, MT.1075, MT.1076, MT.1077, MT.1078, MT.1079, MT.1080, MT.1081, MT.1083, MT.1084, MT.1085, MT.1086, MT.1087, MT.1088, MT.1089, MT.1090, MT.1091, MT.1092, MT.1093, MT.1094, MT.1095, MT.1096, MT.1097, MT.1098, MT.1099, MT.1100, MT.1101, MT.1102, MT.1103, MT.1105

### Ungrouped

| Tag | Count |
| :--- | ---: |
| App | 7 |
| Azure | 3 |
| AzureConfig | 3 |
| CA | 29 |
| Device | 7 |
| Entra | 22 |
| Entra ID Free | 11 |
| Entra ID P1 | 10 |
| Entra ID P2 | 9 |
| EntraOps | 5 |
| Exchange | 9 |
| EXO | 67 |
| Exposure Management | 10 |
| Graph | 13 |
| Group | 2 |
| Intune | 15 |
| License | 2 |
| LongRunning | 15 |
| PIM | 4 |
| Preview | 2 |
| Privileged | 14 |
| Teams | 6 |
| XSPM | 10 |

**Individual tags**: Authentication, Backup, Deprecated, Hybrid, MDI, Recommendation

