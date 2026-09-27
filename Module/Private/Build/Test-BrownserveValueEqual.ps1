<#
.SYNOPSIS
    Performs a deep equality check between two values that may be scalars, arrays or hashtables.
.DESCRIPTION
    Used by the structured 'Merged' file mergers to work out whether a value on disk still matches a
    previously recorded baseline or newly generated value. Hashtables are compared key by key (order
    doesn't matter), arrays are compared element by element (order does matter, matching JSON array
    semantics), everything else falls back to a straight equality check.
#>
function Test-BrownserveValueEqual
{
    [CmdletBinding()]
    param
    (
        # The first value to compare
        [Parameter(Mandatory = $false)]
        $ReferenceValue,

        # The second value to compare
        [Parameter(Mandatory = $false)]
        $DifferenceValue
    )
    process
    {
        if ($null -eq $ReferenceValue -and $null -eq $DifferenceValue)
        {
            return $true
        }
        if ($null -eq $ReferenceValue -or $null -eq $DifferenceValue)
        {
            return $false
        }
        if ($ReferenceValue -is [hashtable] -and $DifferenceValue -is [hashtable])
        {
            $ReferenceKeys = @($ReferenceValue.Keys)
            $DifferenceKeys = @($DifferenceValue.Keys)
            if (@(Compare-Object -ReferenceObject $ReferenceKeys -DifferenceObject $DifferenceKeys).Count -ne 0)
            {
                return $false
            }
            foreach ($Key in $ReferenceKeys)
            {
                if (!(Test-BrownserveValueEqual -ReferenceValue $ReferenceValue[$Key] -DifferenceValue $DifferenceValue[$Key]))
                {
                    return $false
                }
            }
            return $true
        }
        if ($ReferenceValue -is [array] -and $DifferenceValue -is [array])
        {
            if ($ReferenceValue.Count -ne $DifferenceValue.Count)
            {
                return $false
            }
            for ($i = 0; $i -lt $ReferenceValue.Count; $i++)
            {
                if (!(Test-BrownserveValueEqual -ReferenceValue $ReferenceValue[$i] -DifferenceValue $DifferenceValue[$i]))
                {
                    return $false
                }
            }
            return $true
        }
        return ($ReferenceValue -eq $DifferenceValue)
    }
}
