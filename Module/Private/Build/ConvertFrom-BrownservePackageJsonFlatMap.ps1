<#
.SYNOPSIS
    Rebuilds a 'package.json' hashtable from the composite-key flat map produced by
    'ConvertTo-BrownservePackageJsonFlatMap' (and merged by 'Merge-BrownserveKeyedContribution').
.DESCRIPTION
    Composite keys of the form '<group>\0<name>' are regrouped back into 'dependencies', 'devDependencies'
    and 'scripts' objects, each sorted alphabetically by name. Every other key is written back as a
    top-level field, sorted alphabetically.
#>
function ConvertFrom-BrownservePackageJsonFlatMap
{
    [CmdletBinding()]
    param
    (
        # The merged composite-key flat map
        [Parameter(Mandatory = $true)]
        [hashtable]
        $FlatMap
    )
    process
    {
        $Groups = @{ dependencies = [ordered]@{}; devDependencies = [ordered]@{}; scripts = [ordered]@{} }
        $TopLevel = @{}
        foreach ($Key in $FlatMap.Keys)
        {
            if ($Key -match '^(dependencies|devDependencies|scripts)::(.+)$')
            {
                $Groups[$Matches[1]][$Matches[2]] = $FlatMap[$Key]
            }
            else
            {
                $TopLevel[$Key] = $FlatMap[$Key]
            }
        }

        $Result = [ordered]@{}
        foreach ($Key in ($TopLevel.Keys | Sort-Object))
        {
            $Result[$Key] = $TopLevel[$Key]
        }
        foreach ($Group in @('dependencies', 'devDependencies', 'scripts'))
        {
            if ($Groups[$Group].Count -eq 0)
            {
                continue
            }
            $Sorted = [ordered]@{}
            foreach ($Name in ($Groups[$Group].Keys | Sort-Object))
            {
                $Sorted[$Name] = $Groups[$Group][$Name]
            }
            $Result[$Group] = $Sorted
        }
        return $Result
    }
}
