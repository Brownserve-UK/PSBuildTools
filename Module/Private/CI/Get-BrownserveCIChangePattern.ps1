<#
.SYNOPSIS
    Works out the changed-file patterns that should trigger CI for a single component.
.DESCRIPTION
    Reads 'CI.ChangePatterns' from the component's definition. A pattern may contain '{OptionName}' tokens, which
    are replaced with the (regex-escaped) value of that option, and 'CI.OptionChangePatterns' can replace the
    whole list when an option has a given value (e.g. a container 'Context' of '.').
    Patterns are extended regular expressions, matched case-insensitively against paths relative to the
    repository root.
#>
function Get-BrownserveCIChangePattern
{
    [CmdletBinding()]
    param
    (
        # The resolved component
        [Parameter(Mandatory = $true)]
        [BrownserveResolvedComponent]
        $Component,

        # The component's definition
        [Parameter(Mandatory = $true)]
        [BrownserveRepoComponentDefinition]
        $Definition
    )
    process
    {
        $CIData = $Definition.Data.CI
        if (!$CIData -or !$CIData.ChangePatterns)
        {
            return @()
        }
        $Patterns = @($CIData.ChangePatterns)
        if ($CIData.OptionChangePatterns)
        {
            foreach ($Override in $CIData.OptionChangePatterns)
            {
                if ($Component.Options.ContainsKey($Override.Option) -and $Component.Options[$Override.Option] -eq $Override.Value)
                {
                    $Patterns = @($Override.Patterns)
                }
            }
        }
        $Options = $Component.Options
        $Evaluator = {
            param ($Match)
            $OptionName = $Match.Groups[1].Value
            if (!$Options.ContainsKey($OptionName))
            {
                return $Match.Value
            }
            return [regex]::Replace([string]$Options[$OptionName], '[\\.\[\]\(\)\{\}\*\+\?\^\$\|]', '\$0')
        }
        return @($Patterns | ForEach-Object { [regex]::Replace($_, '\{(\w+)\}', $Evaluator) })
    }
}
