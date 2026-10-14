# Schema of the [MaesterTest] attribute (docs/proposals/maester-3.0-test-attributes.md, section 2, and
# the Maester 3.0 design, sections 3.1 and 4).
#
# The engine reads [MaesterTest(...)] from a test file's AST and validates it against this table;
# a test file is never executed to read its metadata. The property list must match
# MaesterTestAttribute in src/Maester.Engine (a unit test compares them).
#
# Property keys:
#   Type             string | string[] | bool
#   Required         Always | BuiltIn (required for tests shipped with Maester) | No
#   NotRequiredWhen  the property is not required when another property has this value, for example
#                    @{ Severity = 'Info' }
#   AllowedValues    closed list, compared case-insensitively and stored in this spelling
#   ValuesFrom       the values are validated against an engine registry instead of a fixed list:
#                    ServiceRegistry, or Taxonomy.Products, Taxonomy.Features, Taxonomy.Areas and
#                    Taxonomy.ResourceTypes (assets/MaesterTaxonomy.psd1). A test shipped with Maester must
#                    use a registry value; a custom test may use any value that fits Pattern and MaxLength
#   Pattern          regular expression each value must match
#   MaxLength        maximum length of each value
#   Default          value used when the property is omitted (documentation; the engine applies it)
#   Description      one line, used by generated docs
@{
    SchemaVersion    = '1.0'

    # Segments of letters and digits (and '_' after the first segment) separated by '.' or '-',
    # starting with a letter and containing at least one digit or separator.
    IdPattern        = '^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$'
    IdMaxLength      = 64

    # ID prefixes that belong to tests shipped with Maester.
    ReservedPrefixes = @('MT.', 'CISA.', 'CIS.', 'EIDSCA.', 'ORCA.', 'AD-', 'AZDO.', 'MT1060.')

    # Names reserved for future properties. Adding one later does not break existing tests.
    ReservedNames    = @('OptionalService', 'TimeoutSeconds')

    # Properties removed in Maester 3.0, with the message the reader gives for each.
    RemovedProperties = @{
        Category = '`Category` was removed in Maester 3.0. Use `Product` and `Feature`; the result''s `Block` is derived from them.'
        Preview  = '`Preview` was removed in Maester 3.0. Use `Lifecycle = ''Preview''`.'
    }

    # Parameter names a test cannot declare for configuration: the engine supplies them.
    ReservedParameterNames    = @('Instance')
    ReservedParameterPrefixes = @('Mt')

    # Types a test parameter may have (section 3.4).
    ParameterTypes   = @('int', 'bool', 'switch', 'string', 'string[]')

    Properties       = @{
        Id                 = @{
            Type        = 'string'
            Required    = 'Always'
            Pattern     = '^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$'
            MaxLength   = 64
            Description = 'Stable identifier. The file is Test.<Id>.ps1.'
        }
        Title              = @{
            Type        = 'string'
            Required    = 'Always'
            Pattern     = '^[^\r\n]+$'
            Description = 'One-line title shown in the report.'
        }
        Product            = @{
            Type        = 'string'
            Required    = 'BuiltIn'
            ValuesFrom  = 'Taxonomy.Products'
            Pattern     = '^[^\r\n]+$'
            MaxLength   = 40
            Description = 'Key of the product where the fix is made, for example entra. An alias such as Entra ID is stored as the key. Groups console progress and the run summary; written to the result as Product.'
        }
        RelatedProduct     = @{
            Type        = 'string[]'
            Required    = 'No'
            ValuesFrom  = 'Taxonomy.Products'
            Pattern     = '^[^\r\n]+$'
            MaxLength   = 40
            Description = 'Keys of other products the test also checks or depends on. Never the same key as Product.'
        }
        Feature            = @{
            Type        = 'string'
            Required    = 'BuiltIn'
            ValuesFrom  = 'Taxonomy.Features'
            Pattern     = '^[^\r\n]+$'
            MaxLength   = 60
            Description = 'Key of the part of the product the test is about, for example conditional-access. One of the features of the test''s product.'
        }
        Area               = @{
            Type        = 'string'
            Required    = 'BuiltIn'
            ValuesFrom  = 'Taxonomy.Areas'
            Pattern     = '^[^\r\n]+$'
            MaxLength   = 60
            Description = 'Key of the security theme, whatever the product, for example authentication.'
        }
        ResourceType       = @{
            Type        = 'string'
            Required    = 'BuiltIn'
            ValuesFrom  = 'Taxonomy.ResourceTypes'
            Pattern     = '^[A-Za-z][A-Za-z0-9]*$'
            Description = 'What a failing result points at, for example Tenant or User.'
        }
        Severity           = @{
            Type          = 'string'
            Required      = 'BuiltIn'
            AllowedValues = @('Critical', 'High', 'Medium', 'Low', 'Info')
            Description   = 'Default severity. The run config may override it.'
        }
        UserImpact         = @{
            Type            = 'string'
            Required        = 'BuiltIn'
            NotRequiredWhen = @{ Severity = 'Info' }
            AllowedValues   = @('Low', 'Medium', 'High')
            Description     = 'How much the recommended fix disrupts end users. Omitted when Severity is Info.'
        }
        ImplementationCost = @{
            Type            = 'string'
            Required        = 'BuiltIn'
            NotRequiredWhen = @{ Severity = 'Info' }
            AllowedValues   = @('Low', 'Medium', 'High')
            Description     = 'How much administrator work the recommended fix takes. Omitted when Severity is Info.'
        }
        Mitre              = @{
            Type        = 'string[]'
            Required    = 'BuiltIn'
            Pattern     = '^(T[0-9]{4}(\.[0-9]{3})?|None)$'
            Description = 'MITRE ATT&CK technique IDs the checked control prevents or detects (T1110, T1110.003), or the single value None.'
        }
        Control            = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[a-z0-9][a-z0-9.\-]*:[^\s,]+$'
            Description = 'Requirements of frameworks the test supports, written <framework-key>:<requirement-id>, beside the benchmark it is named after.'
        }
        Service            = @{
            Type        = 'string[]'
            Required    = 'BuiltIn'
            ValuesFrom  = 'ServiceRegistry'
            Description = 'Services that must all be connected, or None.'
        }
        License            = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[A-Za-z0-9_\-]+(&[A-Za-z0-9_\-]+)*$'
            Description = 'Service plan names. The tenant needs any one element; A&B inside an element means all of them.'
        }
        Permission         = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[^,\r\n]*[^,\s][^,\r\n]*$'
            Description = 'Permissions the test needs, one per element, no commas. Recorded; not enforced.'
        }
        TenantType         = @{
            Type          = 'string[]'
            Required      = 'No'
            AllowedValues = @('Workforce', 'External')
            Default       = @('Workforce')
            Description   = 'Tenant types the test applies to.'
        }
        Cloud              = @{
            Type          = 'string[]'
            Required      = 'No'
            AllowedValues = @('Commercial', 'GCC', 'GCCHigh', 'DoD', 'China', 'Bleu', 'Delos', 'GovSG')
            Description   = 'Clouds the test is valid in. Omitted means all clouds.'
        }
        Platform           = @{
            Type          = 'string[]'
            Required      = 'No'
            AllowedValues = @('Windows', 'Linux', 'MacOS')
            Description   = 'Operating systems the test can run on. Omitted means all platforms.'
        }
        Lifecycle          = @{
            Type          = 'string'
            Required      = 'No'
            AllowedValues = @('Preview', 'Stable', 'Deprecated')
            Default       = 'Stable'
            Description   = 'Preview, Stable or Deprecated. A Preview test is not run unless -IncludePreview or any -Tag is given, or its exact ID is in -TestId.'
        }
        ReplacedBy         = @{
            Type        = 'string'
            Required    = 'No'
            Pattern     = '^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$'
            MaxLength   = 64
            Description = 'ID of the test that took the place of a Deprecated test.'
        }
        LongRunning        = @{
            Type        = 'bool'
            Required    = 'No'
            Default     = $false
            Description = 'Not run unless long-running tests are included.'
        }
        Exclusive          = @{
            Type        = 'bool'
            Required    = 'No'
            Default     = $false
            Description = 'The test must not run concurrently with another test.'
        }
        InstanceSource     = @{
            Type        = 'string'
            Required    = 'No'
            Pattern     = '^[A-Za-z][A-Za-z0-9\-_]*$'
            Description = 'Name of a function in the same file that returns the instances of a family.'
        }
        Tag                = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[^,]*\S[^,]*$'
            Description = 'Free labels of the owner of the test folder, for -Tag and -ExcludeTag. Non-empty, no commas.'
        }
        Author             = @{
            Type        = 'string[]'
            Required    = 'BuiltIn'
            Pattern     = '^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$'
            Description = 'GitHub handles of the initial author(s).'
        }
        Contributor        = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$'
            Description = 'GitHub handles of secondary contributors, in order of first contribution.'
        }
        HelpUrl            = @{
            Type        = 'string'
            Required    = 'No'
            Pattern     = '^https://\S+$'
            Default     = 'The suite template'
            Description = '"Learn more" link.'
        }
    }

    # [MaesterParameter] on a test parameter.
    ParameterAttribute = @{
        Kind = @{
            Type        = 'string'
            Required    = 'Always'
            ValuesFrom  = 'ParameterKindRegistry'
            Pattern     = '^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$'
            Description = 'Name of an entry in the parameter-kind registry, for example Entra.Group.'
        }
    }
}
