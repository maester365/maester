// Pure logic of the test builder: the rules a [MaesterTest] attribute must meet and the text it produces.
// The lists and patterns come from src/data/test-builder.json, which is generated from the module's own files.

export const NEW = "__new__";

const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/;
// The Id and Control patterns of powershell/assets/MaesterTestSchema.psd1, written out so no pattern is built at
// run time. A unit test (TestBuilderData.Tests.ps1) fails when they differ from the schema.
const ID_PATTERN = /^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$/;
const CONTROL_PATTERN = /^[a-z0-9][a-z0-9.\-]*:[^\s,]+$/;
export const HANDLE = /^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$/;

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
  permission: [],
  parameters: [],
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
  permission: [["Graph:Scope:Policy.Read.All"]],
  author: "your-github-handle",
};

// Test parameters. The rules are those of "Parameter names" in the attribute rubric and of Read-MtNativeTest.
export const PARAMETER_TYPES = ["int", "bool", "switch", "string", "string[]"];
export const emptyParameter = { name: "", type: "int", description: "", default: "", min: "", max: "", allowed: "", kind: "", setting: "" };
const RESERVED_PARAMETER_NAMES = ["Force", "Confirm", "WhatIf", "PassThru", "Verbose", "Debug"];
const PASCAL = /^[A-Z][A-Za-z0-9]*$/;
const OWN_SETTING = /^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$/;
const WHOLE = /^-?[0-9]+$/;

// The registry entry of the setting a parameter is bound to, or undefined for a setting of the user's own.
export function settingOf(parameter, data) {
  return parameter.setting ? data.settings.find((s) => s.name.toLowerCase() === parameter.setting.trim().toLowerCase()) : undefined;
}

// A parameter bound to a registered setting takes its type, default and allowed values from the registry.
export function resolveParameter(parameter, data) {
  const setting = settingOf(parameter, data);
  if (!setting) return { ...parameter, allowedValues: splitList(parameter.allowed) };
  const value = setting.default;
  return {
    ...parameter,
    type: setting.type,
    kind: "",
    min: "",
    max: "",
    default: Array.isArray(value) ? value.join(", ") : value === null || value === undefined ? "" : String(value),
    allowedValues: setting.allowedValues || [],
    registered: true,
  };
}

// A new parameter bound to a registered setting, named after it.
export function parameterForSetting(setting) {
  return { ...emptyParameter, name: setting.name.split(".").pop(), setting: setting.name, description: setting.description };
}

export function validateParameters(state, data, add) {
  const builtin = state.mode === "builtin";
  const seen = new Set();
  (state.parameters || []).forEach((raw, index) => {
    const p = resolveParameter(raw, data);
    const name = p.name.trim();
    const label = name || "Parameter " + (index + 1);
    const say = (level, text) => add("parameters", level, label + ": " + text);
    const list = p.type === "string[]" || p.type === "object[]";

    if (!name) say("error", "give it a name.");
    else {
      if (!PASCAL.test(name)) say("error", "use PascalCase, letters and digits only, for example MaximumInactiveDays.");
      if (/^(Max|Min)(?!imum)/.test(name)) say("error", "spell out the limit: " + name.replace(/^Max(?!imum)/, "Maximum").replace(/^Min(?!imum)/, "Minimum") + ".");
      if (/In(Days|Hours|Minutes|Seconds)$/.test(name)) say("error", "a unit is a plain suffix: " + name.replace(/In(Days|Hours|Minutes|Seconds)$/, "$1") + ".");
      if (list && !/s$/.test(name)) say("error", "a list takes a plural name, for example ExcludedGroups.");
      if (RESERVED_PARAMETER_NAMES.some((r) => r.toLowerCase() === name.toLowerCase())) say("error", "that name means something else in PowerShell. Name what turning it on does, for example AllDomains.");
      if (name === "Instance" || /^Mt/.test(name)) say("error", "Instance and names starting with Mt belong to the engine.");
      if (/(Threshold|Value|Number|Count)(Days|Hours|Minutes|Seconds)?$/.test(name) && !/^(Maximum|Minimum)/.test(name)) say("warn", "say what is measured and whether it is an upper or lower limit, for example MaximumInactiveDays.");
      if (seen.has(name.toLowerCase())) say("error", "the test already has a parameter with this name.");
      seen.add(name.toLowerCase());
      const used = data.parameterNames.find((n) => n.name.toLowerCase() === name.toLowerCase());
      if (used && used.type !== p.type) say(builtin ? "error" : "warn", "other tests use this name for a " + used.type + ". One name has one type; choose another name.");
    }

    if (!p.description.trim()) say(builtin ? "error" : "warn", "describe it in one line. Get-MtTest and the docs show the description.");
    else if (/[\r\n]/.test(p.description)) say("error", "the description is one line.");

    const setting = p.setting.trim();
    if (setting && !p.registered) {
      if (builtin) say("error", setting + " is not a registered setting. Choose one from the list, or register it in powershell/assets/MaesterSettings.psd1 in the same pull request.");
      else if (!OWN_SETTING.test(setting)) say("error", "a setting of your own is named Namespace.Key, for example Contoso.Regions.");
    }
    if (p.registered && settingOf(raw, data).connection) say("error", setting + " is a connection setting, which a test does not bind.");

    if (!p.registered) {
      if (p.type === "int") {
        if (!WHOLE.test(String(p.default).trim())) say("error", "give a whole number as the default. A test runs with no configuration.");
        const min = String(p.min).trim();
        const max = String(p.max).trim();
        if ((min && !WHOLE.test(min)) || (max && !WHOLE.test(max))) say("error", "the range is two whole numbers.");
        else if (Boolean(min) !== Boolean(max)) say("error", "a range needs both a lowest and a highest value.");
        else if (min && Number(min) > Number(max)) say("error", "the lowest value of the range is above the highest.");
        else if (min && WHOLE.test(String(p.default).trim()) && (Number(p.default) < Number(min) || Number(p.default) > Number(max))) say("error", "the default is outside the range.");
        else if (!min) say("warn", "give a threshold a range, so a typo in the config is caught.");
      }
      if (p.type === "bool" && !/^(true|false)$/i.test(String(p.default).trim() || "false")) say("error", "the default is true or false.");
      if (p.allowedValues.length && p.type === "string" && p.default.trim() && !p.allowedValues.includes(p.default.trim())) say("error", "the default is not one of the allowed values.");
      if (p.allowedValues.length && !["string", "string[]"].includes(p.type)) say("error", "allowed values are for a string or a list of strings.");
    }
  });
}

const psValue = (text) => "'" + String(text).replace(/'/g, "''") + "'";

// The lines of the param() block.
export function parameterLines(state, data) {
  const parameters = (state.parameters || []).map((raw) => resolveParameter(raw, data)).filter((p) => p.name.trim());
  return parameters.map((p, index) => {
    const lines = [];
    const pad = "        ";
    lines.push(pad + "# " + (p.description.trim().replace(/[\r\n]+/g, " ") || "Describe what this value changes."));
    const named = [];
    if (p.kind && !p.registered) named.push("Kind = " + psValue(p.kind));
    if (p.setting.trim()) named.push("Setting = " + psValue(p.registered ? settingOf(p, data).name : p.setting.trim()));
    if (named.length) lines.push(pad + "[MaesterParameter(" + named.join(", ") + ")]");
    if (p.type === "int" && String(p.min).trim() && String(p.max).trim()) lines.push(pad + "[ValidateRange(" + String(p.min).trim() + ", " + String(p.max).trim() + ")]");
    if (p.allowedValues.length) lines.push(pad + "[ValidateSet(" + p.allowedValues.map(psValue).join(", ") + ")]");
    const items = splitList(p.default);
    let value = "";
    if (p.type === "int") value = " = " + (WHOLE.test(String(p.default).trim()) ? String(p.default).trim() : "0");
    else if (p.type === "bool") value = " = " + (/^true$/i.test(String(p.default).trim()) ? "$true" : "$false");
    else if (p.type === "string") value = " = " + psValue(p.default.trim());
    else if (p.type === "string[]") value = " = @(" + items.map(psValue).join(", ") + ")";
    else if (p.type === "object[]") value = " = @()";
    lines.push(pad + "[" + p.type + "] $" + p.name.trim() + value + (index < parameters.length - 1 ? "," : ""));
    return lines.join("\n");
  });
}

// How an administrator sets the parameters: the shared settings once, the rest on the test's row.
export function buildConfigExample(state, data) {
  const parameters = (state.parameters || []).map((raw) => resolveParameter(raw, data)).filter((p) => p.name.trim());
  if (!parameters.length) return "";
  const sample = (p) => {
    const first = p.allowedValues[0];
    if (p.type === "int") return WHOLE.test(String(p.default).trim()) ? Number(p.default) : 0;
    if (p.type === "bool" || p.type === "switch") return true;
    if (p.type === "string") return first || p.default.trim() || "value";
    if (p.type === "object[]") return p.registered && settingOf(p, data).name === "EmergencyAccessAccounts" ? [{ Type: "User", UserPrincipalName: "BreakGlass1@contoso.com" }] : [{}];
    if (p.kind === "Entra.Domain" || (p.registered && settingOf(p, data).kind === "Entra.Domain")) return ["contoso-old.com"];
    return first ? [first] : splitList(p.default).length ? splitList(p.default) : ["value"];
  };
  const config = {};
  const bound = parameters.filter((p) => p.setting.trim());
  const own = parameters.filter((p) => !p.setting.trim());
  if (bound.length) {
    config.GlobalSettings = {};
    bound.forEach((p) => (config.GlobalSettings[p.registered ? settingOf(p, data).name : p.setting.trim()] = sample(p)));
  }
  if (own.length) {
    const values = {};
    own.forEach((p) => (values[p.name.trim()] = sample(p)));
    config.TestSettings = [{ Id: state.id.trim() || "CT.1001", Parameters: values }];
  }
  return JSON.stringify(config, null, 2);
}

// The registered settings the test binds under the setting's own name: New-MtTest -Setting writes these.
export function scaffoldedSettings(state, data) {
  return (state.parameters || [])
    .filter((p) => settingOf(p, data) && p.name.trim() === settingOf(p, data).name)
    .map((p) => settingOf(p, data).name);
}

// The form filled in from an existing test (a row of /data/builder-tests.json). It loads what the attribute
// declares. References the engine adds, the related controls of the test's benchmark requirement, are left out,
// because a test does not repeat them.
export function stateFromTest(test, data) {
  const list = (value) => (Array.isArray(value) ? value.filter((v) => v !== null && v !== "") : []);
  const suite = data.suites.find((s) => s.idPrefixes.some((prefix) => test.Id.startsWith(prefix)));
  const derived = new Set();
  list(test.Control).forEach((control) => {
    const framework = data.frameworks.find((f) => control.startsWith(f.key + ":"));
    const requirement = framework && framework.requirements.find((r) => framework.key + ":" + r.id === control);
    ((requirement && requirement.related) || []).forEach((r) => derived.add(r));
  });
  const mitre = list(test.Mitre);
  const services = list(test.Service);
  const text = (value) => (Array.isArray(value) ? value.join(", ") : value === null || value === undefined ? "" : String(value));
  return {
    ...emptyState,
    mode: "builtin",
    suite: suite ? suite.id : emptyState.suite,
    id: test.Id,
    title: test.Title || "",
    functionName: test.FunctionName && test.FunctionName !== functionNameFor(test.Id) ? test.FunctionName : "",
    product: test.Product || "",
    relatedProducts: list(test.RelatedProduct),
    feature: test.Feature || "",
    area: test.Area || "",
    resourceType: test.ResourceType || "",
    severity: test.Severity || "",
    userImpact: test.UserImpact || "",
    implementationCost: test.ImplementationCost || "",
    mitreNone: mitre.length === 1 && mitre[0] === "None",
    mitre: mitre.filter((m) => m !== "None"),
    controls: list(test.Control).filter((c) => !derived.has(c)),
    serviceNone: services.length === 1 && services[0] === "None",
    services: services.filter((x) => x !== "None"),
    license: list(test.License).map((element) => element.split("&").map((x) => x.trim()).filter(Boolean)),
    permission: list(test.Permission).map((element) => element.split("|").map((x) => x.trim()).filter(Boolean)),
    tenantType: list(test.TenantType),
    cloud: list(test.Cloud),
    platform: list(test.Platform),
    lifecycle: test.Lifecycle || "Stable",
    replacedBy: test.ReplacedBy || "",
    longRunning: Boolean(test.LongRunning),
    exclusive: Boolean(test.Exclusive),
    author: list(test.Author).join(", "),
    contributor: list(test.Contributor).join(", "),
    parameters: list(test.Parameters).map((p) => ({
      ...emptyParameter,
      name: p.Name,
      type: p.Type,
      description: p.Description || "",
      default: p.Type === "switch" ? "" : text(p.Default),
      min: p.Range ? String(p.Range[0]) : "",
      max: p.Range ? String(p.Range[1]) : "",
      allowed: list(p.AllowedValues).join(", "),
      kind: p.Kind || "",
      setting: p.Setting || "",
    })),
  };
}

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
  const idPattern = ID_PATTERN;

  // Id
  const id = state.id.trim();
  if (!id) add("id", "error", "Give the test an ID.");
  else {
    if (!idPattern.test(id) || id.length > data.idMaxLength)
      add("id", "error", "Use letters and digits separated by dots or dashes, starting with a letter, for example CT.1001. At most " + data.idMaxLength + " characters.");
    const reserved = data.reservedPrefixes.find((p) => id.toLowerCase().startsWith(p.toLowerCase()));
    if (builtin) {
      const suite = data.suites.find((s) => s.id === state.suite);
      if (suite && !suite.idPrefixes.some((p) => id.toLowerCase().startsWith(p.toLowerCase())))
        add("id", "error", "An ID in the " + suite.name + " suite starts with " + suite.idPrefixes.join(" or ") + ".");
    } else if (reserved) {
      add("id", "error", "The prefix " + reserved + " is reserved for the tests shipped with Maester and for Maester Packs. Use your own, for example CT.");
    }
  }
  if (!builtin) {
    const prefix = state.customPrefix.trim();
    if (!/^[A-Za-z][A-Za-z0-9]*$/.test(prefix)) add("prefix", "error", "A prefix is letters and digits, starting with a letter, for example CT or CONTOSO.");
    else if (data.reservedPrefixes.some((p) => (prefix + ".").toLowerCase().startsWith(p.toLowerCase()) || (prefix + "-").toLowerCase().startsWith(p.toLowerCase())))
      add("prefix", "error", prefix + " is reserved for the tests shipped with Maester and for Maester Packs. Choose your own prefix.");
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
  const controlPattern = CONTROL_PATTERN;
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
  // The engine rejects an alternative listed twice in a requirement, and a requirement listed twice, compared
  // without case.
  state.permission.forEach((group) => {
    const seen = new Set();
    group.forEach((p) => {
      if (seen.has(p.toLowerCase())) add("permission", "error", p + " is listed more than once in a requirement. Remove one of them.");
      seen.add(p.toLowerCase());
    });
  });
  const seenPermissions = new Set();
  permissionElements(state).forEach((element) => {
    const key = element.toLowerCase();
    if (seenPermissions.has(key)) add("permission", "error", element + " is listed more than once. Remove one of the requirements.");
    seenPermissions.add(key);
  });
  state.permission.flat().forEach((p) => {
    const parsed = parsePermission(p);
    if (!parsed) {
      add("permission", "error", p + " is not <Service>:<Kind>:<Name>.");
      return;
    }
    const service = data.services.find((s) => s.name.toLowerCase() === parsed.service.toLowerCase() || s.aliases.some((a) => a.toLowerCase() === parsed.service.toLowerCase()));
    if (!service) {
      if (builtin) add("permission", "error", parsed.service + " is not in the service registry.");
      return;
    }
    if (!service.permissionKinds.some((k) => k.kind.toLowerCase() === parsed.kind.toLowerCase())) {
      add("permission", builtin ? "error" : "warn", parsed.kind + " is not a kind of permission of " + service.name + ". Use " + service.permissionKinds.map((k) => k.kind).join(", ") + ".");
    }
    // Service = 'None' is written when serviceNone is set, whatever services were ticked before.
    const declared = state.serviceNone ? [] : state.services;
    if (builtin && !declared.includes(service.name)) add("permission", "error", p + " names " + service.name + ", which is not one of the services of the test. Add it under Services.");
  });

  validateParameters(state, data, add);

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

// Permission: <Service>:<Kind>:<Name>. The name is everything after the second colon, so it may contain colons.
export function parsePermission(text) {
  const m = /^\s*([A-Za-z][A-Za-z0-9.\-]*):([A-Za-z]+):([^,|\r\n]*[^,|\s])\s*$/.exec(String(text || ""));
  return m ? { service: m[1], kind: m[2], name: m[3].trim() } : null;
}

// Permission: the identity needs every element; alternatives joined with | inside an element are any one.
export function permissionElements(state) {
  return state.permission.filter((group) => group.length).map((group) => group.join(" | "));
}

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
  arr("Permission", permissionElements(state));
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

export function buildPs1(state, data) {
  const lines = data ? parameterLines(state, data) : [];
  const paramBlock = lines.length ? "param(\n" + lines.join("\n\n") + "\n    )" : "param()";
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
    ${paramBlock}

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

// A prompt for an AI coding assistant, made from the form: what the test should verify, where the guidance is,
// the files to create and how to check them. A test for Maester is written in a clone of the repository, whose
// agents and skills the prompt points at; a custom test needs only the published guides.
export function buildAiPrompt(state, data, goal) {
  const builtin = state.mode === "builtin";
  const id = state.id.trim() || (builtin ? "MT.1234" : "CT.1001");
  const folder = folderFor(state, data);
  const what = goal.trim() || "<Describe the setting to check, the value you expect and why it matters.>";
  const ps1 = buildPs1(state, data);
  const lines = [];
  if (builtin) {
    lines.push(
      "I want to add a security check to Maester. Work in my clone of https://github.com/maester365/maester.",
      "",
      "What the check should verify:",
      what,
      "",
      "Follow the repository's own guidance before you write anything:",
      "- AGENTS.md",
      "- the maester-test-expert skill: .github/skills/maester-test-expert/SKILL.md",
      "- website/docs/writing-tests/index.mdx",
      "- website/docs/writing-tests/attribute-rubric.md",
      "",
      "Steps:",
      "1. Look for a test that already checks this setting, in every suite" + (state.product && state.feature && state.product !== NEW && state.feature !== NEW ? " (Get-MtTest -Product " + state.product + " -Feature " + state.feature + ", and a search of tests/ for the setting or endpoint)" : " (Get-MtTest, and a search of tests/ for the setting or endpoint)") + ". If one exists, stop and tell me.",
      "2. Create " + folder + "/Test." + id + ".ps1 and " + folder + "/Test." + id + ".md. Start from the code below, which I made in the test builder at https://maester.dev/test-builder. Check each attribute value against the rubric and tell me which you would change and why.",
      "3. Write the function body. Read the tenant through Maester's helpers and the session cache, declare Service and License instead of checking connections or licences in code, use no outer try/catch, return $true or $false, and report with Add-MtTestResultDetail. Give the function a name that says what it checks.",
      "4. Write the .md: what is checked and why it matters, numbered remediation steps with a direct link to the admin portal page, and the Microsoft Learn article.",
      "5. Validate: Get-MtTest " + id + ", regenerate the golden fixture (./build/golden/Export-MtGoldenFixture.ps1), git add the new files, then run ./powershell/tests/pester.ps1 and fix what it flags.",
      "",
      "Do not commit, push or open a pull request until I have reviewed the files." + (/^MT\.\d+$/.test(id) ? " The ID " + id + " must be reserved on https://github.com/maester365/maester/issues/697 first; remind me if I have not said it is." : ""),
    );
  } else {
    lines.push(
      "Write a custom Maester test for me. Maester (https://maester.dev) is a PowerShell framework that checks the security configuration of Microsoft 365.",
      "",
      "What the test should verify:",
      what,
      "",
      "Read these guides first:",
      "- https://maester.dev/docs/writing-tests/first-custom-test.md",
      "- https://maester.dev/docs/writing-tests.md",
      "- https://maester.dev/docs/writing-tests/formatting-test-results.md",
      "",
      "Steps:",
      "1. Create " + folder + "/Test." + id + ".ps1 and " + folder + "/Test." + id + ".md. Start from the code below, which I made in the test builder at https://maester.dev/test-builder. Keep the ID and the attribute values unless one is wrong, and tell me if you change one.",
      "2. Write the function body. Use only commands the Maester module exports, such as Invoke-MtGraphRequest and Add-MtTestResultDetail. Declare Service and License instead of checking connections or licences in code, use no outer try/catch, and return $true or $false.",
      "3. Write the .md: what is checked and why it matters, and numbered steps to fix it with a link to the admin portal page.",
      "4. Check the files without a tenant: Get-MtTest -Path " + folder + ". Then run the test: Invoke-MtTest -Path " + folder + "/Test." + id + ".ps1",
      "",
      "If you cannot run commands, give me both files in full and the commands to run. Do not invent Graph endpoints or property names: say so when you are not sure one exists.",
    );
  }
  lines.push("", "Test." + id + ".ps1:", "", ps1);
  return lines.join("\n");
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
  const settings = scaffoldedSettings(state, data);
  if (settings.length) parts.push("-Setting " + psList(settings));
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
