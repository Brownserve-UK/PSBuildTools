<#
.SYNOPSIS
    Removes a set of common parameters from a function's documentation.
.DESCRIPTION
    This works around a bug in platyPS (https://github.com/PowerShell/platyPS/issues/595) that isn't likely to be
    fixed until the the PlatyPS rewrite has been completed.
    Should more common parameters be added to PowerShell in the future, this script will need to be updated.
#>
function Remove-PlatyPSCommonParameter
{
    [CmdletBinding()]
    param
    (
        # The content to check for common parameters.
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [psobject[]]
        $Content,

        # The common parameters to remove.
        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [string[]]
        $Parameter = @('-ProgressAction')
    )

    begin
    {
        $Return = @()
    }

    process
    {
        foreach ($FileToProcess in $Content)
        {
            $StringContent = $FileToProcess.ToString()
            # Regex adapted from: https://github.com/PowerShell/platyPS/issues/595#issuecomment-1820971702
            $Parameter | ForEach-Object {
                $ParameterName = $_
                if (!$ParameterName.StartsWith('-'))
                {
                    $ParameterName = "-$ParameterName"
                }
                $StringContent = $StringContent -replace "(?m)^### $_\r?\n[\S\s]*?(?=#{2,3}?)", ''
                $StringContent = $StringContent -replace " \[$_\s?.*?]"
            }
            $ProcessedContent = $StringContent | Format-BrownserveContent | Select-Object -ExpandProperty Content
            $FileToProcess.Content = $ProcessedContent
            $Return += $FileToProcess
        }
    }

    end
    {
        if ($Return.Count -gt 0)
        {
            return $Return
        }
        else
        {
            return $null
        }
    }
}
