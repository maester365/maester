# Report icons

The Maester HTML report shows Microsoft's product and feature icons beside product and feature names. It loads
them from here (`https://maester.dev/report-icons/v1/...`) instead of embedding them, which keeps the report
small. A report opened offline shows the names without icons.

- `v1/products/`: one icon per product key in `powershell/assets/MaesterTaxonomy.psd1`; see its README.
- `v1/features/`: the feature icons; `report/src/lib/featureIcons.ts` maps each feature to a file; see its README.

Reports already generated keep asking for these paths, so never change or remove a file in `v1`. To change an
icon, add a `v2` folder and point the report at it.
