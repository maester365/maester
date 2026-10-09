# Schema of the [MaesterTest] attribute (Maester 3.0 design, sections 3.1, 3.2 and 4).
#
# The engine reads [MaesterTest(...)] from a test file's AST and validates it against this table;
# a test file is never executed to read its metadata. The property list must match
# MaesterTestAttribute in src/Maester.Engine (a unit test compares them).
#
# Property keys:
#   Type           string | string[] | bool
#   Required       Always | BuiltIn (required for tests shipped with Maester) | No
#   AllowedValues  closed list, compared case-insensitively
#   ValuesFrom     the values are validated against an engine registry instead of a fixed list
#   Pattern        regular expression each value must match
#   MaxLength      maximum length of each value
#   Default        value used when the property is omitted (documentation; the engine applies it)
#   Description    one line, used by generated docs
@{
    SchemaVersion    = '1.0'

    # Segments of letters and digits (and '_' after the first segment) separated by '.' or '-',
    # starting with a letter and containing at least one digit or separator.
    IdPattern        = '^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$'
    IdMaxLength      = 64

    # ID prefixes that belong to tests shipped with Maester.
    ReservedPrefixes = @('MT.', 'CISA.', 'CIS.', 'EIDSCA.', 'ORCA.', 'AD-', 'AZDO.', 'MT1060.')

    # Names reserved for future properties. Adding one later does not break existing tests.
    ReservedNames    = @('Product', 'GraphScope', 'OptionalService', 'TimeoutSeconds', 'Deprecated')

    # Parameter names a test cannot declare for configuration: the engine supplies them.
    ReservedParameterNames    = @('Instance')
    ReservedParameterPrefixes = @('Mt')

    # Types a test parameter may have (section 3.4).
    ParameterTypes   = @('int', 'bool', 'switch', 'string', 'string[]')

    Properties       = @{
        Id                = @{
            Type        = 'string'
            Required    = 'Always'
            Pattern     = '^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$'
            MaxLength   = 64
            Description = 'Stable identifier. The file is Test.<Id>.ps1.'
        }
        Title             = @{
            Type        = 'string'
            Required    = 'Always'
            Pattern     = '^[^\r\n]+$'
            Description = 'One-line title shown in the report.'
        }
        Severity          = @{
            Type          = 'string'
            Required      = 'BuiltIn'
            AllowedValues = @('Critical', 'High', 'Medium', 'Low', 'Info')
            Description   = 'Default severity. The run config may override it.'
        }
        Category          = @{
            Type        = 'string'
            Required    = 'No'
            Default     = 'The suite default, else Custom'
            Description = 'Report grouping, written to the result as Block.'
        }
        Tag               = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[^,]*\S[^,]*$'
            Description = 'Free selection tags for -Tag and -ExcludeTag. Non-empty, no commas.'
        }
        Preview           = @{
            Type        = 'bool'
            Required    = 'No'
            Default     = $false
            Description = 'Not run unless -IncludePreview or any -Tag is given.'
        }
        LongRunning       = @{
            Type        = 'bool'
            Required    = 'No'
            Default     = $false
            Description = 'Not run unless long-running tests are included.'
        }
        Service           = @{
            Type        = 'string[]'
            Required    = 'BuiltIn'
            ValuesFrom  = 'ServiceRegistry'
            Description = 'Services that must all be connected, or None.'
        }
        License = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[A-Za-z0-9_\-]+(&[A-Za-z0-9_\-]+)*$'
            Description = 'Service plan names. The tenant needs any one element; A&B inside an element means all of them.'
        }
        TenantType        = @{
            Type          = 'string[]'
            Required      = 'No'
            AllowedValues = @('Workforce', 'External')
            Default       = @('Workforce')
            Description   = 'Tenant types the test applies to.'
        }
        Cloud             = @{
            Type          = 'string[]'
            Required      = 'No'
            AllowedValues = @('Commercial', 'GCC', 'GCCHigh', 'DoD', 'China', 'Bleu', 'Delos', 'GovSG')
            Description   = 'Clouds the test is valid in. Omitted means all clouds.'
        }
        Platform          = @{
            Type          = 'string[]'
            Required      = 'No'
            AllowedValues = @('Windows', 'Linux', 'MacOS')
            Description   = 'Operating systems the test can run on. Omitted means all platforms.'
        }
        InstanceSource    = @{
            Type        = 'string'
            Required    = 'No'
            Pattern     = '^[A-Za-z][A-Za-z0-9\-_]*$'
            Description = 'Name of a function in the same file that returns the instances of a family.'
        }
        Exclusive         = @{
            Type        = 'bool'
            Required    = 'No'
            Default     = $false
            Description = 'The test must not run concurrently with another test.'
        }
        Author            = @{
            Type        = 'string[]'
            Required    = 'BuiltIn'
            Pattern     = '^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$'
            Description = 'GitHub handles of the initial author(s).'
        }
        Contributor       = @{
            Type        = 'string[]'
            Required    = 'No'
            Pattern     = '^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$'
            Description = 'GitHub handles of secondary contributors, in order of first contribution.'
        }
        HelpUrl           = @{
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
