<#
.SYNOPSIS
    Resolves a list of repository component names (plus their options) into a validated, ordered set of
    components ready for 'Compare-BrownserveRepository' to consume.
.DESCRIPTION
    'Core' is always included. Every component's 'Requires' are expanded transitively. Options are validated
    against each component's schema (unknown component, unknown option, wrong type, missing required option
    all fail fast) and defaults are applied for anything the caller didn't supply.
    The returned components are always in the same, deterministic order regardless of the order they were
    requested in, so that collections built from them (gitignores, paket dependencies, paths, etc) come out
    byte-identical between runs.
#>
function Resolve-BrownserveRepoComponent
{
    [CmdletBinding()]
    param
    (
        # The components to resolve, 'Core' is always included automatically
        [Parameter(Mandatory = $false)]
        [string[]]
        $Name = @(),

        # Per-component options, keyed by component name
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Options = @{},

        # The directory that contains one sub-directory per component, each holding a 'component.psd1' file
        [Parameter(Mandatory = $false)]
        [string]
        $ComponentsDirectory = $Script:BrownserveRepoComponentsDirectory
    )
    begin
    {
        # The order components come out in, this keeps generated output deterministic
        $CanonicalOrder = @(
            'Core',
            'ReleaseLifecycle',
            'PowerShellModule',
            'RustBinary',
            'ContainerImage',
            'DirectoryArchive',
            'MkDocs',
            'AstroDocs'
        )

        function Test-BrownserveRepoComponentOptionType
        {
            param ($Value, [string]$TypeName)
            switch ($TypeName)
            {
                'bool' { return $Value -is [bool] }
                'string' { return $Value -is [string] }
                'int' { return $Value -is [int] }
                'array' { return $Value -is [array] }
                default
                {
                    $ResolvedType = $TypeName -as [type]
                    if (!$ResolvedType)
                    {
                        throw "Unknown option type '$TypeName'."
                    }
                    return $Value -is $ResolvedType
                }
            }
        }

        try
        {
            $AvailableDefinitions = Get-BrownserveRepoComponentDefinition -ComponentsDirectory $ComponentsDirectory -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to load component definitions.`n$($_.Exception.Message)"
        }
    }
    process
    {
        $Requested = @(@('Core') + @($Name) | Select-Object -Unique)

        foreach ($RequestedName in $Requested)
        {
            if (!$AvailableDefinitions.ContainsKey($RequestedName))
            {
                throw "Unknown component '$RequestedName'."
            }
        }

        $ResolvedNames = [System.Collections.Generic.HashSet[string]]::new()
        $Queue = [System.Collections.Generic.Queue[string]]::new()
        $Requested | ForEach-Object { $Queue.Enqueue($_) }
        while ($Queue.Count -gt 0)
        {
            $Current = $Queue.Dequeue()
            if ($ResolvedNames.Add($Current))
            {
                if (!$AvailableDefinitions.ContainsKey($Current))
                {
                    throw "Unknown component '$Current' required by another component."
                }
                $AvailableDefinitions[$Current].Requires | ForEach-Object { $Queue.Enqueue($_) }
            }
        }

        foreach ($OptionComponentName in $Options.Keys)
        {
            if (!$ResolvedNames.Contains($OptionComponentName))
            {
                throw "Options were supplied for component '$OptionComponentName' but it was not requested (directly or via 'Requires')."
            }
        }

        $OrderedNames = @($CanonicalOrder | Where-Object { $ResolvedNames.Contains($_) })
        $OrderedNames += @($ResolvedNames | Where-Object { $CanonicalOrder -notcontains $_ } | Sort-Object)

        $Resolved = @()
        foreach ($ComponentName in $OrderedNames)
        {
            $Definition = $AvailableDefinitions[$ComponentName]
            $SuppliedOptions = @{}
            if ($Options.ContainsKey($ComponentName))
            {
                $SuppliedOptions = $Options[$ComponentName]
            }

            foreach ($SuppliedName in $SuppliedOptions.Keys)
            {
                if ($Definition.Options.Name -notcontains $SuppliedName)
                {
                    throw "Unknown option '$SuppliedName' for component '$ComponentName'."
                }
            }

            $FinalOptions = @{}
            foreach ($OptionDefinition in $Definition.Options)
            {
                if ($SuppliedOptions.ContainsKey($OptionDefinition.Name))
                {
                    $Value = $SuppliedOptions[$OptionDefinition.Name]
                    if ($null -ne $Value -and !(Test-BrownserveRepoComponentOptionType -Value $Value -TypeName $OptionDefinition.Type))
                    {
                        throw "Invalid value for option '$($OptionDefinition.Name)' on component '$ComponentName'; expected type '$($OptionDefinition.Type)'."
                    }
                    $FinalOptions[$OptionDefinition.Name] = $Value
                }
                elseif ($OptionDefinition.Required)
                {
                    throw "Component '$ComponentName' requires the option '$($OptionDefinition.Name)' to be supplied."
                }
                else
                {
                    $FinalOptions[$OptionDefinition.Name] = $OptionDefinition.Default
                }
            }

            $Resolved += [BrownserveResolvedComponent]::new($ComponentName, $FinalOptions)
        }
    }
    end
    {
        return $Resolved
    }
}
