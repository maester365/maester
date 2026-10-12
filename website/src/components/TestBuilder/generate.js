// Pure logic of the test builder: the rules a [MaesterTest] attribute must meet and the text it produces.
// The lists and patterns come from src/data/test-builder.json, which is generated from the module's own files.

export const NEW = "__new__";

const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const HANDLE = /^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$/;

export const emptyState = {
  mode: "builtin",
  suite: "Maester",
  customPrefix: "CT",
  id: "",
  title: "",
  functionName: "",
  product: "",
  newProduct: { key: "", name: "" },
  relatedProducts: [],
  feature: "",
  newFeature: { key: "", name: "" },
  area: "",
  newArea: { key: "", name: "", description: "" },
  resourceType: "",
  newResourceType: { key: "", description: "" },
  severity: "",
  userImpact: "",
  implementationCost: "",
  mitreNone: false,
  mitre: [],
  controls: [],
  services: [],
  serviceNone: false,
  license: [],
  permission: "",
  tenantType: [],
  cloud: [],
  platform: [],
  lifecycle: "Stable",
  replacedBy: "",
  longRunning: false,
  exclusive: false,
  tags: "",
  author: "",
  contributor: "",
};

export const exampleState = {
  ...emptyState,
  id: "MT.1234",
  title: "At least one Conditional Access policy blocks device code flow.",
  product: "entra",
  feature: "conditional-access",
  area: "authentication",
  resourceType: "Tenant",
  severity: "High",
  userImpact: "Low",
  implementationCost: "Low",
  mitre: ["T1078.004", "T1528", "T1566"],
  services: ["Graph"],
  license: [["AAD_PREMIUM"]],
  author: "your-github-handle",
};

export function splitList(text) {
  return String(text || "")
    .split(/[\n,]/)
    .map((x) => x.trim())
    .filter(Boolean);
}

// The effective value of a registry field: the chosen key, or the key of the new entry being proposed.
export function effective(state, field) {
  const value = state[field];
  if (value !== NEW) return value;
  const fresh = state["new" + field[0].toUpperCase() + field.slice(1)];
  return (fresh && fresh.key) || "";
}

// Same rule as New-MtTest: Test- followed by the ID's segments in Pascal case.
export function functionNameFor(id) {
  const parts = String(id || "")
    .split(/[.\-_]/)
    .filter(Boolean)
    .map((p) => p[0].toUpperCase() + p.slice(1));
  return "Test-" + (parts.join("") || "MyCheck");
}

export function functionName(state) {
  return state.functionName.trim() || functionNameFor(state.id);
}

function parentOf(id) {
  return id.split(".")[0];
}

export function validate(state, data) {
  const out = [];
  const add = (field, level, text) => out.push({ field, level, text });
  const builtin = state.mode === "builtin";
  const idPattern = new RegExp(data.idPattern);

  // Id
  const id = state.id.trim();
  if (!id) add("id", "error", "Give the test an ID.");
  else {
    if (!idPattern.test(id) || id.length > data.idMaxLength)
      add("id", "error", "Use letters and digits separated by dots or dashes, starting with a letter, for example CT.1001. At most " + data.idMaxLength + " characters.");
    const reserved = data.reservedPrefixes.find((p) => id.toLowerCase().startsWith(p.toLowerCase()));
    if (builtin) {
      const suite = data.suites.find((s) => s.id === state.suite);
      if (suite && !new RegExp(suite.idPattern).test(id))
        add("id", "error", "An ID in the " + suite.name + " suite must match " + suite.idPattern + ".");
    } else if (reserved) {
      add("id", "error", "The prefix " + reserved + " belongs to the tests shipped with Maester. Use your own, for example CT.");
    }
  }
  if (!builtin) {
    const prefix = state.customPrefix.trim();
    if (!/^[A-Za-z][A-Za-z0-9]*$/.test(prefix)) add("prefix", "error", "A prefix is letters and digits, starting with a letter, for example CT or CONTOSO.");
    else if (data.reservedPrefixes.some((p) => (prefix + ".").toLowerCase().startsWith(p.toLowerCase()) || (prefix + "-").toLowerCase().startsWith(p.toLowerCase())))
      add("prefix", "error", prefix + " belongs to the tests shipped with Maester. Choose your own prefix.");
  }

  // Title
  if (!state.title.trim()) add("title", "error", "Give the test a one-line title.");

  const fn = functionName(state);
  if (!/^[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9]+$/.test(fn)) add("functionName", "error", "A function name is Verb-Noun with letters and digits only, for example Test-MtGuestInvite.");

  // Classification
  const product = effective(state, "product");
  const feature = effective(state, "feature");
  const area = effective(state, "area");
  const resourceType = effective(state, "resourceType");
  const knownProduct = data.products.find((p) => p.key === product);

  if (builtin) {
    if (!product && state.product !== NEW) add("product", "error", "Choose the product where the fix is made.");
    if (!feature && state.feature !== NEW) add("feature", "error", "Choose the feature the test is about.");
    if (!area && state.area !== NEW) add("area", "error", "Choose the security area.");
    if (!resourceType && state.resourceType !== NEW) add("resourceType", "error", "Choose what a failing result points at.");
  }
  if (state.product === NEW) {
    if (!KEBAB.test(state.newProduct.key)) add("product", "error", "A product key is lowercase words joined by dashes, for example power-platform.");
    else if (data.products.some((p) => p.key === state.newProduct.key)) add("product", "error", "That product key already exists. Choose it from the list.");
    if (!state.newProduct.name.trim()) add("product", "error", "Give the new product a display name.");
  }
  if (state.feature === NEW) {
    if (!KEBAB.test(state.newFeature.key)) add("feature", "error", "A feature key is lowercase words joined by dashes, for example access-reviews.");
    else if (knownProduct && knownProduct.features.some((f) => f.key === state.newFeature.key)) add("feature", "error", "That feature already exists for this product. Choose it from the list.");
    if (!state.newFeature.name.trim()) add("feature", "error", "Give the new feature a display name.");
  } else if (builtin && feature && knownProduct && !knownProduct.features.some((f) => f.key === feature)) {
    add("feature", "error", "That feature belongs to another product. Choose one of " + knownProduct.name + "'s features.");
  }
  if (state.area === NEW) {
    if (!KEBAB.test(state.newArea.key)) add("area", "error", "An area key is lowercase words joined by dashes.");
    else if (data.areas.some((a) => a.key === state.newArea.key)) add("area", "error", "That area already exists. Choose it from the list.");
    if (!state.newArea.name.trim() || !state.newArea.description.trim()) add("area", "error", "Give the new area a name and say what it is used for.");
  }
  if (state.resourceType === NEW) {
    if (!/^[A-Z][A-Za-z0-9]*$/.test(state.newResourceType.key)) add("resourceType", "error", "A resource type is one word in Pascal case, for example AccessPackage.");
    else if (data.resourceTypes.some((r) => r.key.toLowerCase() === state.newResourceType.key.toLowerCase())) add("resourceType", "error", "That resource type already exists. Choose it from the list.");
    if (!state.newResourceType.description.trim()) add("resourceType", "error", "Describe the new resource type in one line.");
  } else if (resourceType && !/^[A-Za-z][A-Za-z0-9]*$/.test(resourceType)) {
    add("resourceType", "error", "A resource type is one word of letters and digits.");
  }
  if (product && state.relatedProducts.includes(product)) add("relatedProducts", "error", "A related product is never the same as the product.");

  // Priority
  if (builtin && !state.severity) add("severity", "error", "Choose a severity.");
  if (builtin && state.severity && state.severity !== "Info") {
    if (!state.userImpact) add("userImpact", "error", "Choose the user impact of the fix.");
    if (!state.implementationCost) add("implementationCost", "error", "Choose the implementation cost of the fix.");
  }

  // Mitre
  const known = new Set(data.attack.techniques.map((t) => t.id));
  if (builtin && !state.mitreNone && state.mitre.length === 0) add("mitre", "error", "List the ATT&CK techniques the control prevents or detects, or choose None.");
  if (!state.mitreNone) {
    if (state.mitre.length > 5) add("mitre", "error", "List at most five techniques.");
    state.mitre.filter((m) => !known.has(m)).forEach((m) => add("mitre", "error", m + " is not in ATT&CK " + data.attack.version + "."));
    state.mitre
      .filter((m) => m.includes(".") && state.mitre.includes(parentOf(m)))
      .forEach((m) => add("mitre", "error", "Do not list " + parentOf(m) + " together with its own sub-technique " + m + "."));
    const perParent = {};
    state.mitre.filter((m) => m.includes(".")).forEach((m) => (perParent[parentOf(m)] = (perParent[parentOf(m)] || 0) + 1));
    Object.keys(perParent)
      .filter((p) => perParent[p] >= 3)
      .forEach((p) => add("mitre", "warn", "Three or more sub-techniques of " + p + " apply. List " + p + " instead."));
  }

  // Control
  const controlPattern = new RegExp(data.properties.Control.pattern);
  state.controls.filter((c) => !controlPattern.test(c)).forEach((c) => add("control", "error", c + " is not written <framework-key>:<requirement-id>, for example cisa-scuba:MS.AAD.3.1."));
  const nistIds = new Set(data.nist.controls.map((c) => c.id));
  const suite = data.suites.find((s) => s.id === state.suite);
  const suiteFrameworks = builtin ? data.frameworks.filter((f) => suite && f.suite === suite.id) : [];
  state.controls.forEach((c) => {
    const [key, ...rest] = c.split(":");
    const id = rest.join(":");
    const framework = data.frameworks.find((f) => f.key === key);
    if (framework && !framework.requirements.some((r) => r.id === id)) add("control", "warn", id + " is not in " + framework.file + " yet. Add it there in the same pull request.");
    if (key === data.nist.key && !nistIds.has(id)) add("control", builtin ? "error" : "warn", id + " is not a control of " + data.nist.name + ". Use an ID such as IA-2(1).");
  });
  if (suiteFrameworks.length && !state.controls.some((c) => suiteFrameworks.some((f) => c.startsWith(f.key + ":")))) {
    add("control", "error", "A test in the " + suite.name + " suite names the requirement it implements, for example " + suiteFrameworks[0].key + ":" + suiteFrameworks[0].requirements[0].id + ". Put it first.");
  }

  // Requirements
  if (builtin && !state.serviceNone && state.services.length === 0) add("services", "error", "Choose the services the test needs, or None.");
  const licensePattern = /^[A-Za-z0-9_-]+$/;
  state.license
    .flat()
    .filter((l) => !licensePattern.test(l))
    .forEach((l) => add("license", "error", l + " is not a service plan name. Use letters, digits, _ and -."));

  // Lifecycle
  if (state.replacedBy.trim()) {
    if (!idPattern.test(state.replacedBy.trim())) add("replacedBy", "error", "ReplacedBy is the ID of another test.");
    if (state.lifecycle !== "Deprecated") add("replacedBy", "warn", "ReplacedBy is for a Deprecated test.");
  }

  // People and tags
  const authors = splitList(state.author);
  if (builtin && authors.length === 0) add("author", "error", "Give the GitHub handle of the author.");
  authors.concat(splitList(state.contributor)).filter((a) => !HANDLE.test(a)).forEach((a) => add("author", "error", a + " is not a GitHub handle."));
  if (builtin && splitList(state.tags).length) add("tags", "error", "Built-in tests do not carry tags. Product, feature, area, suite and severity each have an attribute.");

  return out;
}

const quote = (v) => "'" + String(v).replace(/'/g, "''") + "'";
const list = (values) => (values.length === 1 ? quote(values[0]) : "(" + values.map(quote).join(", ") + ")");

// License: the tenant needs any one element; plans joined with & inside an element are all needed.
export function licenseElements(state) {
  return state.license.filter((group) => group.length).map((group) => group.join("&"));
}

// The named arguments of [MaesterTest], in the order of the design.
export function attributeEntries(state) {
  const entries = [];
  const put = (name, text) => entries.push([name, text]);
  const str = (name, value) => value && put(name, quote(value));
  const arr = (name, values) => values.length && put(name, list(values));

  put("Id", quote(state.id.trim() || "CT.1001"));
  put("Title", quote(state.title.trim() || "Describe the requirement in one line."));
  str("Product", effective(state, "product"));
  arr("RelatedProduct", state.relatedProducts);
  str("Feature", effective(state, "feature"));
  str("Area", effective(state, "area"));
  str("ResourceType", effective(state, "resourceType"));
  str("Severity", state.severity);
  if (state.severity !== "Info") {
    str("UserImpact", state.userImpact);
    str("ImplementationCost", state.implementationCost);
  }
  if (state.mitreNone) put("Mitre", quote("None"));
  else arr("Mitre", state.mitre);
  arr("Control", state.controls);
  if (state.serviceNone) put("Service", quote("None"));
  else arr("Service", state.services);
  arr("License", licenseElements(state));
  arr("Permission", splitList(state.permission));
  arr("TenantType", state.tenantType);
  arr("Cloud", state.cloud);
  arr("Platform", state.platform);
  if (state.lifecycle && state.lifecycle !== "Stable") put("Lifecycle", quote(state.lifecycle));
  str("ReplacedBy", state.replacedBy.trim());
  if (state.longRunning) put("LongRunning", "$true");
  if (state.exclusive) put("Exclusive", "$true");
  arr("Tag", splitList(state.tags));
  arr("Author", splitList(state.author));
  arr("Contributor", splitList(state.contributor));
  return entries;
}

export function buildPs1(state) {
  const attribute = attributeEntries(state)
    .map(([name, text]) => "        " + name + " = " + text)
    .join(",\n");
  const title = state.title.trim() || "Describe the requirement in one line.";
  return `function ${functionName(state)} {
    <#
    .SYNOPSIS
    ${title}

    .DESCRIPTION
    Describe the control and what the check evaluates.
    #>
    [MaesterTest(
${attribute}
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Read the tenant state. The engine has already checked that the services above are connected,
    # and turns an uncaught error into an Error result, so no connection check or try/catch is needed.
    $settings = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy'

    $passed = $null -ne $settings

    $resultMarkdown = if ($passed) { 'Well done. The tenant meets this requirement.' } else { 'The tenant does not meet this requirement.' }
    Add-MtTestResultDetail -Result $resultMarkdown

    return $passed
}
`;
}

export function buildMd() {
  return `Describe what this test checks and why it matters.

#### Remediation action

Explain how to fix a failing result, step by step.

#### Related links

- [Microsoft Learn](https://learn.microsoft.com)

<!--- Results --->
%TestResult%
`;
}

export function folderFor(state, data) {
  if (state.mode !== "builtin") return "./custom";
  const suite = data.suites.find((s) => s.id === state.suite);
  if (!suite) return "./tests";
  const product = effective(state, "product");
  if (suite.productFolders.length && product) return "./" + suite.folder + "/" + product;
  return "./" + suite.folder;
}

// New-MtTest writes both files. It takes a subset of the attributes; the rest are added by hand.
export function buildCommand(state, data) {
  const parts = ["New-MtTest -Id " + (state.id.trim() || "CT.1001"), "-Title " + quote(state.title.trim() || "Describe the requirement in one line.")];
  const psList = (values) => values.join(", ");
  if (state.severity) parts.push("-Severity " + state.severity);
  parts.push("-Service " + (state.serviceNone || state.services.length === 0 ? "None" : psList(state.services)));
  [
    ["Product", effective(state, "product")],
    ["Feature", effective(state, "feature")],
    ["Area", effective(state, "area")],
    ["ResourceType", effective(state, "resourceType")],
    ["UserImpact", state.severity === "Info" ? "" : state.userImpact],
    ["ImplementationCost", state.severity === "Info" ? "" : state.implementationCost],
  ].forEach(([name, value]) => value && parts.push("-" + name + " " + (/^[A-Za-z0-9-]+$/.test(value) ? value : quote(value))));
  if (state.mitreNone) parts.push("-Mitre None");
  else if (state.mitre.length) parts.push("-Mitre " + psList(state.mitre));
  parts.push("-Path " + folderFor(state, data));
  return parts.join(" `\n    ");
}

const GENERATED_BY_NEW_MTTEST = ["Id", "Title", "Product", "Feature", "Area", "ResourceType", "Severity", "UserImpact", "ImplementationCost", "Mitre", "Service"];

export function addByHand(state) {
  return attributeEntries(state)
    .map(([name]) => name)
    .filter((name) => !GENERATED_BY_NEW_MTTEST.includes(name));
}

// What a pull request must contain besides the two test files, for values that are new to the registries.
export function registryChanges(state, data) {
  const changes = [];
  const taxonomy = "powershell/assets/MaesterTaxonomy.psd1";
  if (state.mode !== "builtin") return changes;
  if (state.product === NEW && state.newProduct.key) {
    const featureLine = state.feature === NEW && state.newFeature.key ? `\n                @{ Key = ${quote(state.newFeature.key)}; Name = ${quote(state.newFeature.name)} }` : "\n                # the features tests can be about";
    changes.push({
      file: taxonomy,
      what: "Add the product to the Products list.",
      snippet: `        @{\n            Key      = ${quote(state.newProduct.key)}\n            Name     = ${quote(state.newProduct.name)}\n            Aliases  = @(${quote(state.newProduct.name)})\n            Features = @(${featureLine}\n            )\n        }`,
    });
  } else if (state.feature === NEW && state.newFeature.key) {
    const product = data.products.find((p) => p.key === state.product);
    changes.push({
      file: taxonomy,
      what: "Add the feature to the Features list of " + (product ? product.name : "the product") + ".",
      snippet: `                @{ Key = ${quote(state.newFeature.key)}; Name = ${quote(state.newFeature.name)} }`,
    });
  }
  if (state.area === NEW && state.newArea.key) {
    changes.push({
      file: taxonomy,
      what: "Add the area to the Areas list.",
      snippet: `        @{ Key = ${quote(state.newArea.key)}; Name = ${quote(state.newArea.name)}; Description = ${quote(state.newArea.description)} }`,
    });
    changes.push({
      file: "website/docs/writing-tests/attribute-rubric.md",
      what: "Add a row to the Area table, and say in the pull request why no existing area fits.",
      snippet: "| `" + state.newArea.key + "` | " + state.newArea.description + " |",
    });
  }
  if (state.resourceType === NEW && state.newResourceType.key) {
    changes.push({
      file: taxonomy,
      what: "Add the resource type to the ResourceTypes list.",
      snippet: `        @{ Key = ${quote(state.newResourceType.key)}; Description = ${quote(state.newResourceType.description)} }`,
    });
  }
  // A requirement that is not in a shipped framework's file yet is added to it.
  state.controls.forEach((control) => {
    const [key, ...rest] = control.split(":");
    const framework = data.frameworks.find((f) => f.key === key);
    if (framework && !framework.requirements.some((r) => r.id === rest.join(":"))) {
      changes.push({ file: framework.file, what: "Add the requirement to Requirements, with its level or criticality.", snippet: `{ "Id": "${rest.join(":")}" }` });
    }
  });
  if (changes.length) {
    changes.push({
      file: "website/src/data/test-builder.json",
      what: "Regenerate this page's data so the new value shows up here.",
      snippet: "./build/website/Update-MtTestBuilderData.ps1",
    });
  }
  return changes;
}

// The ID with another prefix: MT.1234 becomes CT.1234. An empty ID gets the first number.
export function withPrefix(id, prefix) {
  const tail = String(id || "").trim().replace(/^[A-Za-z][A-Za-z0-9]*[.\-]?/, "");
  return prefix + "." + (tail || "1001");
}
