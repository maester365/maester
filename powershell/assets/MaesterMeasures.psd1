# The measure registry of the defender's path (docs/proposals/defenders-path.md, section 11).
#
# A measure is a figure the engine reads from Graph for a step that is a state of the tenant, such as the share of
# devices that sign in and are compliant. A step names a measure in the step catalogue
# (powershell/assets/steps/<product>.json) as "Measure": { "Key": "<key>", "MinimumShare": <1 to 100> }, and the step
# is done when the figure meets its threshold. A measure is not a test: it has no ID, no result row and no place in
# pass rates.
#
# Keys of each entry:
#   Key         lowercase kebab-case, the name a step's Measure uses
#   Function    the internal reader in powershell/internal/services/<service>/. It reads through the Graph cache and
#               returns Count (objects that meet the bar), Total and Objects (those that fall short, as Type, Id and
#               DisplayName)
#   Title       one line, shown with the figure, for example 'Devices that sign in are compliant'
#   Unit        what is counted, plural, for example 'devices'
#   Service     services that must all be connected, as in a test's Service attribute
#   License     service plans, any one of which is enough, as in a test's License attribute (optional)
#   Permission  permissions the reader needs, as in a test's Permission attribute (optional)
@{
    Measures = @()
}
