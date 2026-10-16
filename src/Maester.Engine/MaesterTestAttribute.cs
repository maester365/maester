using System;

// These two types are deliberately in the GLOBAL namespace. PowerShell resolves an attribute
// written as [MaesterTest(...)] by probing 'MaesterTest' and 'MaesterTestAttribute' in the global
// namespace (and a few System.* namespaces) of every loaded assembly. A namespaced type is not
// found that way: the function defines fine but fails at call time with "Cannot find the type for
// custom attribute 'MaesterTest'".
//
// The engine never instantiates these attributes to read metadata. It reads [MaesterTest(...)]
// from the AST and validates it against the schema table (powershell/assets/MaesterTestSchema.psd1),
// so a test file is never executed during discovery. The types exist so that the function can be
// defined and invoked. Keep the properties here and the schema table in step; a unit test
// compares them.

/// <summary>
/// Metadata for a Maester native test, placed above the param() block of the test function:
/// <code>
/// function Test-MtExample {
///     [MaesterTest(Id = 'CONTOSO.1001', Title = 'Example', Severity = 'High', Service = 'Graph')]
///     [CmdletBinding()]
///     param()
/// }
/// </code>
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public sealed class MaesterTestAttribute : Attribute
{
    // Identity

    /// <summary>Stable identifier, for example MT.1198. The file is Test.&lt;Id&gt;.ps1.</summary>
    public string Id { get; set; }

    /// <summary>One-line title shown in the report.</summary>
    public string Title { get; set; }

    // Classification: what the test is about. Keys come from the taxonomy registry
    // (powershell/assets/MaesterTaxonomy.psd1); a custom test may use any value.

    /// <summary>Key of the product where the fix is made, for example entra. Written to the result as Product.</summary>
    public string Product { get; set; }

    /// <summary>Keys of other products the test also checks or depends on. Never the same key as Product.</summary>
    public string[] RelatedProduct { get; set; }

    /// <summary>Key of the part of the product the test is about, for example conditional-access.</summary>
    public string Feature { get; set; }

    /// <summary>Key of the security theme, whatever the product, for example authentication.</summary>
    public string Area { get; set; }

    /// <summary>What a failing result points at, for example Tenant or User.</summary>
    public string ResourceType { get; set; }

    // Priority: what to fix first.

    /// <summary>Critical, High, Medium, Low or Info. The run config may override it.</summary>
    public string Severity { get; set; }

    /// <summary>Low, Medium or High: how much the recommended fix disrupts end users.</summary>
    public string UserImpact { get; set; }

    /// <summary>Low, Medium or High: how much administrator work the recommended fix takes.</summary>
    public string ImplementationCost { get; set; }

    // Mappings

    /// <summary>MITRE ATT&amp;CK technique IDs the checked control prevents or detects (T1110, T1110.003), or None.</summary>
    public string[] Mitre { get; set; }

    /// <summary>Framework controls the test supports, written &lt;framework-key&gt;:&lt;control-id&gt;.</summary>
    public string[] Control { get; set; }

    // Applicability

    /// <summary>Services that must all be connected, or None.</summary>
    public string[] Service { get; set; }

    /// <summary>Service plan names; the tenant needs any one element. 'A&amp;B' inside an element means all of them.</summary>
    public string[] License { get; set; }

    /// <summary>Permissions the test needs, one per element. Recorded; not enforced.</summary>
    public string[] Permission { get; set; }

    /// <summary>Workforce or External.</summary>
    public string[] TenantType { get; set; }

    /// <summary>Commercial, GCC, GCCHigh, DoD, China, Bleu, Delos or GovSG.</summary>
    public string[] Cloud { get; set; }

    /// <summary>Windows, Linux or MacOS.</summary>
    public string[] Platform { get; set; }

    // Lifecycle

    /// <summary>Preview, Stable or Deprecated. A Preview test is not run unless previews are included.</summary>
    public string Lifecycle { get; set; }

    /// <summary>ID of the test that took the place of a Deprecated test.</summary>
    public string ReplacedBy { get; set; }

    // Execution

    /// <summary>Not run unless long-running tests are included.</summary>
    public bool LongRunning { get; set; }

    /// <summary>The test must not run concurrently with another test.</summary>
    public bool Exclusive { get; set; }

    /// <summary>Name of a function in the same file that returns the instances of a family.</summary>
    public string InstanceSource { get; set; }

    /// <summary>Free labels of the owner of the test folder, used by -Tag and -ExcludeTag.</summary>
    public string[] Tag { get; set; }

    // Credits and docs

    /// <summary>GitHub handles of the initial author(s).</summary>
    public string[] Author { get; set; }

    /// <summary>GitHub handles of secondary contributors, in order of first contribution.</summary>
    public string[] Contributor { get; set; }

    /// <summary>"Learn more" link. Defaults to the suite's template.</summary>
    public string HelpUrl { get; set; }
}

/// <summary>
/// Declares the semantic kind of a test parameter so that a UI can offer a picker, and the engine can
/// validate the value and resolve a display name:
/// <code>
/// [MaesterParameter(Kind = 'Entra.Group')]
/// [string[]] $ExcludedGroups
/// </code>
/// Kinds are defined in the parameter-kind registry, not here.
/// </summary>
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field, AllowMultiple = false)]
public sealed class MaesterParameterAttribute : Attribute
{
    /// <summary>Name of an entry in the parameter-kind registry, for example Entra.Group.</summary>
    public string Kind { get; set; }
}
