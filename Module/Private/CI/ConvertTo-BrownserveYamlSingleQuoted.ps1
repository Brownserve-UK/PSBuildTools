<#
.SYNOPSIS
    Wraps a string in single quotes for use as a YAML scalar.
.DESCRIPTION
    Single quoted YAML scalars take everything literally, so the only character that needs escaping is the
    single quote itself, which is doubled.
#>
function ConvertTo-BrownserveYamlSingleQuoted
{
    [CmdletBinding()]
    param
    (
        # The string to quote
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Value
    )
    process
    {
        return "'$($Value -replace "'", "''")'"
    }
}
