<#
.SYNOPSIS
    Works out whether a marker-delimited 'Merged' file's generated section has been edited in a way that
    conflicts with regenerating it.
.DESCRIPTION
    A conflict exists when the generated section currently on disk differs from both the hash recorded in
    the previous manifest and the newly generated section. When there's no previous recorded hash (a fresh
    file, or a v1 manifest that never tracked one), there's nothing to conflict with, so this always returns
    '$false' in that case. A manual-section edit never reaches this cmdlet at all, since only the generated
    section is passed in.
#>
function Test-BrownserveMarkerConflict
{
    [CmdletBinding()]
    param
    (
        # The generated section as currently found on disk. Pass '$null' when the file doesn't exist yet.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string[]]
        $DiskGenerated,

        # The generated section's hash as recorded in the previous manifest, if any
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]
        $RecordedHash,

        # The freshly generated section
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]
        $NewGenerated
    )
    process
    {
        if ($null -eq $DiskGenerated -or [string]::IsNullOrEmpty($RecordedHash))
        {
            return $false
        }
        $DiskHash = Get-BrownserveManagedFileHash -Content $DiskGenerated
        $NewHash = Get-BrownserveManagedFileHash -Content $NewGenerated
        if ($DiskHash -ne $RecordedHash -and $DiskHash -ne $NewHash)
        {
            return $true
        }
        return $false
    }
}
