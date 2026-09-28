<#
.SYNOPSIS
    Computes the repository manifest hash for a piece of generated file content.
.DESCRIPTION
    Joins the given content lines with a single line feed (so the hash is stable regardless of the
    line ending the file is eventually written with), hashes the UTF-8 bytes with SHA256 and returns
    the result in the 'sha256:<hex>' format used by the '.brownserve_repository_manifest' 'Files' map.
    A trailing blank line is appended if one isn't already present, matching 'Set-BrownserveContent's
    default 'InsertFinalNewline' behaviour, so the hash reflects the content as it's actually written
    to disk regardless of whether the caller's array already carries that trailing entry.
#>
function Get-BrownserveManagedFileHash
{
    [CmdletBinding()]
    param
    (
        # The content lines to hash
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]
        $Content
    )
    process
    {
        $NormalisedContent = $Content
        if ($NormalisedContent.Count -gt 0 -and $NormalisedContent[-1] -ne '')
        {
            $NormalisedContent += ''
        }
        $Joined = $NormalisedContent -join "`n"
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Joined)
        $Hasher = [System.Security.Cryptography.SHA256]::Create()
        try
        {
            $HashBytes = $Hasher.ComputeHash($Bytes)
        }
        finally
        {
            $Hasher.Dispose()
        }
        $Hex = ($HashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
        return "sha256:$Hex"
    }
}
