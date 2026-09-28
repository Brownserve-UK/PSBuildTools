<#
.SYNOPSIS
    Splits a freshly generated array of content lines around a literal marker line.
.DESCRIPTION
    'Select-BrownserveContent' (from Brownserve.PSCommon) needs a '[BrownserveContent]' object to work with,
    which is a private type we can't construct from outside that module. Since the content we're splitting
    here is content we've just generated ourselves (so we already know the marker is present, verbatim,
    exactly once), a simple line search is all that's needed.
    Returns a '[pscustomobject]' with 'Before' (every line before the marker) and 'After' (every line after
    the marker), excluding the marker line itself.
#>
function Split-BrownserveContentAtMarker
{
    [CmdletBinding()]
    param
    (
        # The content lines to split
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]
        $Content,

        # The literal marker line to split on
        [Parameter(Mandatory = $true)]
        [string]
        $Marker
    )
    process
    {
        $MarkerIndex = [array]::IndexOf($Content, $Marker)
        if ($MarkerIndex -lt 0)
        {
            throw "Could not find the marker '$Marker' in the given content."
        }
        $Before = @()
        if ($MarkerIndex -gt 0)
        {
            $Before = $Content[0..($MarkerIndex - 1)]
        }
        $After = @()
        if ($MarkerIndex -lt ($Content.Count - 1))
        {
            $After = $Content[($MarkerIndex + 1)..($Content.Count - 1)]
        }
        return [pscustomobject]@{
            Before = $Before
            After  = $After
        }
    }
}
