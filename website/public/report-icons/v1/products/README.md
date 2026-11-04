# Product icons

Microsoft product icons shown beside product names in the report. Each file is named after the product key in
`powershell/assets/MaesterTaxonomy.psd1`; the report uses a neutral tile with the product's initials for a product
that has no file here.

- Source: [DanielBradley1/msicons](https://github.com/DanielBradley1/msicons) (msicons.com), commit `3d57443ed444`, taken on
  2026-11-02. Minified (whitespace removed, coordinates rounded to two decimals); shapes and colours unchanged.
- The icons are Microsoft's. Microsoft permits their use in architectural diagrams, training materials and
  documentation, unchanged and with the product's name near the icon, and not to represent another product
  ([Entra icons](https://learn.microsoft.com/entra/architecture/architecture-icons),
  [Azure icons](https://learn.microsoft.com/azure/architecture/icons/)).

| File | Product | msicons path |
| --- | --- | --- |
| entra.svg | Entra ID | entra/Microsoft Entra ID color icon.svg |
| defender.svg | Defender | apps/Defender.svg |
| intune.svg | Intune | intune/Microsoft-intune.svg |
| sharepoint.svg | SharePoint | sharepoint/microsoft-office-sharepoint-2025.svg |
| teams.svg | Teams | apps/Microsoft Teams.svg |
| azure.svg | Azure | other/10018-icon-service-Azure-A.svg |
| azure-devops.svg | Azure DevOps | devops/10261-icon-service-Azure-DevOps.svg |
| copilot-studio.svg | Copilot Studio | Copilot-studio/CopilotStudio_scalable.svg |
| fabric.svg | Microsoft Fabric | fabric/fabric_color.svg (unchanged) |
| ad.svg | Active Directory | Microsoft/dark-blue-Organization.svg, the same file as `features/organization.svg` |

`purview.svg` (Microsoft Purview) is not from msicons: it is
[Microsoft_Purview_Logo.svg](https://commons.wikimedia.org/wiki/File:Microsoft_Purview_Logo.svg) from Wikimedia Commons,
by Microsoft (source azure.com), licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) there.
Taken on 2026-11-02 and minified (comments and layout attributes removed, coordinates rounded to one decimal);
shapes and colours unchanged, and the file stays under CC BY-SA 4.0. Microsoft's terms above apply to it as well.

`microsoft-365.svg` (Microsoft 365) is not from msicons either: it is
[Microsoft_365_(2022).svg](https://commons.wikimedia.org/wiki/File:Microsoft_365_(2022).svg) from Wikimedia Commons,
by Microsoft (source microsoft365.com), marked public domain there and trademarked. Taken on 2026-11-02 and minified
(comments and title removed, coordinates rounded to two decimals); shapes and colours unchanged. Microsoft's terms
above apply to it.

`exchange.png` (Exchange Online) is not from msicons either: it is `logos/exchange/2019-current-full-color/exchange-128x128.png`
from [loryanstrant/MicrosoftCloudLogos](https://github.com/loryanstrant/MicrosoftCloudLogos), commit `297d4a545767`, taken
on 2026-11-02 and unchanged. That repository has no licence file and points to Microsoft's
[trademark and branding guidelines](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/branding);
the logo is Microsoft's, under the terms above.

msicons has no icon for Exchange Online, Microsoft 365, Active Directory or GitHub. Active Directory has no product
icon of its own there, so `ad.svg` is msicons' generic organization icon, which the site's Active Directory suite
mark also uses.

`github.svg` (GitHub) is the `mark-github-24` icon from [primer/octicons](https://github.com/primer/octicons), tag
`v19.33.0` (commit `cc4e12df6ff8`), taken on 2026-11-05, unchanged and under the MIT licence. It has no fill, so it
draws black; the report and the site invert it in dark mode. GitHub's [logo guidelines](https://github.com/logos)
allow the mark in black or white, unchanged.
