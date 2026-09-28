<#
.SYNOPSIS
    Flattens a parsed 'package.json' hashtable into the composite-key shape 'Merge-BrownserveKeyedContribution'
    expects.
.DESCRIPTION
    The 'dependencies', 'devDependencies' and 'scripts' objects are flattened to one key per entry, keyed as
    '<group>\0<name>', so that an individual dependency or script can be tracked, conflicted and removed on
    its own. Every other top-level field is kept as a single key holding its whole value.
#>
function ConvertTo-BrownservePackageJsonFlatMap
{
    [CmdletBinding()]
    param
    (
        # The parsed 'package.json' content
        [Parameter(Mandatory = $true)]
        [hashtable]
        $PackageJson
    )
    process
    {
        $Flat = [ordered]@{}
        $NestedGroups = @('dependencies', 'devDependencies', 'scripts')
        foreach ($Group in $NestedGroups)
        {
            if ($PackageJson.ContainsKey($Group))
            {
                foreach ($Name in ($PackageJson[$Group].Keys | Sort-Object))
                {
                    $Flat["$Group::$Name"] = $PackageJson[$Group][$Name]
                }
            }
        }
        foreach ($Key in ($PackageJson.Keys | Sort-Object))
        {
            if ($Key -in $NestedGroups)
            {
                continue
            }
            $Flat[$Key] = $PackageJson[$Key]
        }
        return $Flat
    }
}
