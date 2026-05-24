<#
.SYNOPSIS
    Adds a set of common parameters to a function's documentation footer.
.DESCRIPTION
    This works around a bug in platyPS (https://github.com/PowerShell/platyPS/issues/595) that isn't likely to be
    fixed until the the PlatyPS rewrite has been completed.
    Should more common parameters be added to PowerShell in the future, this script will need to be updated.
#>
function Add-PlatyPSCommonParameter
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
            $SupportedCommonParamPattern = '(?m)^This cmdlet supports the common parameters:(?<common_params>.+?)\.'
            if ($StringContent -match $SupportedCommonParamPattern)
            {
                $CommonParams = $Matches['common_params'] -replace ',', '' -split ' ' |
                    Where-Object {$_ -match '^-'}
                if (!$CommonParams)
                {
                    throw 'Failed to extract common parameters from the supported common parameters section.'
                }
                $Parameter | ForEach-Object {
                    $ParameterName = $_
                    if (!$ParameterName.StartsWith('-'))
                    {
                        $ParameterName = "-$ParameterName"
                    }
                    if ($ParameterName -notin $CommonParams)
                    {
                        $CommonParams += $ParameterName
                    }
                }
                $CommonParams = $CommonParams | Sort-Object
                $CommonParams[-1] = "and $($CommonParams[-1])"
                $CommonParams = $CommonParams -join ', '
                $StringContent = $StringContent -replace $SupportedCommonParamPattern, "This cmdlet supports the common parameters: $CommonParams."
                $ProcessedContent = $StringContent | Format-BrownserveContent | Select-Object -ExpandProperty Content
                $FileToProcess.Content = $ProcessedContent
                $Return += $FileToProcess
            }
            else
            {
                throw 'Failed to find the supported common parameters section.'
            }
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
