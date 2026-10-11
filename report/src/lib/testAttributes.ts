// The typed attributes that Maester 3.0 (result schema 2.1) writes on each test row, and the Taxonomy
// object of the result that carries their display names. Results from Maester 2.x and rows of
// Pester-format tests have none of these fields, so every helper copes with a missing value and the
// report shows nothing for them.

interface TaxonomyEntry {
  Key: string
  Name?: string | null
}

export interface Taxonomy {
  Products?: TaxonomyEntry[] | null
  // A feature key is scoped to its product.
  Features?: (TaxonomyEntry & { Product?: string | null })[] | null
  Areas?: TaxonomyEntry[] | null
  ResourceTypes?: TaxonomyEntry[] | null
  Attack?: {
    Version?: string | null
    Techniques?: { Id: string; Name?: string | null; Tactics?: string[] | null }[] | null
    Tactics?: { Id: string; Name?: string | null }[] | null
  } | null
}

// The requirement of a published benchmark that a test implements, with facts about it such as Level.
export interface Benchmark {
  Framework?: string | null
  Version?: string | null
  Requirement?: string | null
  Level?: string | null
}

export interface TestAttributes {
  Product?: string | null
  RelatedProduct?: string[] | null
  Feature?: string | null
  Area?: string | null
  ResourceType?: string | null
  UserImpact?: string | null
  ImplementationCost?: string | null
  // ATT&CK technique IDs, or the single value None.
  Mitre?: string[] | null
  // Framework controls the test supports, written <framework-key>:<control-id>.
  Control?: string[] | null
  Benchmark?: Benchmark | null
  Lifecycle?: string | null
  ReplacedBy?: string | null
  Service?: string[] | null
  License?: string[] | null
  Permission?: string[] | null
  Suite?: string | null
  Source?: string | null
}

interface AttackTechnique {
  id: string
  name: string
  url: string
}

type MaybeTaxonomy = Taxonomy | null | undefined

function toText(value: unknown): string {
  return value === null || value === undefined ? "" : String(value)
}

// PowerShell can write a one-item list as a single value.
function toList(value: unknown): string[] {
  if (value === null || value === undefined) return []
  return (Array.isArray(value) ? value : [value]).map(toText).filter(Boolean)
}

// A custom test may use a value of its own. It has no entry in the taxonomy and is shown as written.
function findName(entries: TaxonomyEntry[] | null | undefined, key: string): string {
  return toText(entries?.find((entry) => entry.Key === key)?.Name) || key
}

function getProductName(taxonomy: MaybeTaxonomy, product: unknown): string {
  return findName(taxonomy?.Products, toText(product))
}

export function getAreaName(taxonomy: MaybeTaxonomy, area: unknown): string {
  return findName(taxonomy?.Areas, toText(area))
}

function getResourceTypeName(taxonomy: MaybeTaxonomy, resourceType: unknown): string {
  return findName(taxonomy?.ResourceTypes, toText(resourceType))
}

function getFeatureName(taxonomy: MaybeTaxonomy, test: TestAttributes): string {
  const feature = toText(test.Feature)
  const entry = taxonomy?.Features?.find((entry) => entry.Key === feature && entry.Product === test.Product)
  return toText(entry?.Name) || feature
}

// The same feature name exists under more than one product (Anti-phishing under Exchange Online and
// Defender), so a feature listed on its own carries its product.
export function getFeatureLabel(taxonomy: MaybeTaxonomy, test: TestAttributes): string {
  const feature = getFeatureName(taxonomy, test)
  const product = getProductName(taxonomy, test.Product)
  return feature && product ? `${feature} (${product})` : feature
}

// https://attack.mitre.org/techniques/T1078/004/ for the sub-technique T1078.004.
function getAttackTechniqueUrl(id: string): string {
  return `https://attack.mitre.org/techniques/${id.split(".").map(encodeURIComponent).join("/")}/`
}

// Nothing for a test that maps to no technique (the single value None).
export function getAttackTechniques(taxonomy: MaybeTaxonomy, test: TestAttributes): AttackTechnique[] {
  return toList(test.Mitre)
    .filter((id) => id.toLowerCase() !== "none")
    .map((id) => ({
      id,
      name: toText(taxonomy?.Attack?.Techniques?.find((technique) => technique.Id === id)?.Name),
      url: getAttackTechniqueUrl(id),
    }))
}

// Framework, version, requirement and level of the benchmark requirement, when the row has one.
// A version can contain a comma (ScubaGear main, 2026-10-11), so the parts are set apart by a bullet.
export function getBenchmarkText(test: TestAttributes): string {
  const benchmark = test.Benchmark
  if (!benchmark || typeof benchmark !== "object") return ""
  return [
    [benchmark.Framework, benchmark.Version].map(toText).filter(Boolean).join(" "),
    benchmark.Requirement ? `requirement ${benchmark.Requirement}` : "",
    benchmark.Level ? `level ${benchmark.Level}` : "",
  ].filter(Boolean).join(" • ")
}

export function getControls(test: TestAttributes): string[] {
  return toList(test.Control)
}

// The attributes with a single value, in the order the report shows them.
const singleValueFields: { label: string; value: (taxonomy: MaybeTaxonomy, test: TestAttributes) => string }[] = [
  { label: "Product", value: (taxonomy, test) => getProductName(taxonomy, test.Product) },
  { label: "Feature", value: getFeatureName },
  { label: "Area", value: (taxonomy, test) => getAreaName(taxonomy, test.Area) },
  { label: "Resource type", value: (taxonomy, test) => getResourceTypeName(taxonomy, test.ResourceType) },
  { label: "User impact", value: (_taxonomy, test) => toText(test.UserImpact) },
  { label: "Implementation cost", value: (_taxonomy, test) => toText(test.ImplementationCost) },
]

// A benchmark requirement and a control are something a test supports. The report never words them as compliance.
export const attackTechniquesLabel = "ATT&CK techniques"
export const benchmarkLabel = "Supports benchmark"
export const controlsLabel = "Supports controls"

// Label and display value of the single-value attributes that the row has.
export function getTestAttributeFields(taxonomy: MaybeTaxonomy, test: TestAttributes): { label: string; value: string }[] {
  return singleValueFields
    .map((field) => ({ label: field.label, value: field.value(taxonomy, test) }))
    .filter((field) => field.value)
}

export function hasTestAttributes(test: TestAttributes): boolean {
  return getTestAttributeFields(null, test).length > 0 ||
    getAttackTechniques(null, test).length > 0 ||
    getBenchmarkText(test) !== "" ||
    getControls(test).length > 0
}

// Columns the Excel export adds for the attributes: the same fields as the test detail view.
export const testAttributeExportHeaders = [
  ...singleValueFields.map((field) => field.label),
  attackTechniquesLabel,
  benchmarkLabel,
  controlsLabel,
]

export function getTestAttributeExportValues(taxonomy: MaybeTaxonomy, test: TestAttributes): string[] {
  return [
    ...singleValueFields.map((field) => field.value(taxonomy, test)),
    getAttackTechniques(taxonomy, test).map((technique) => `${technique.id} ${technique.name}`.trim()).join(", "),
    getBenchmarkText(test),
    getControls(test).join(", "),
  ]
}
