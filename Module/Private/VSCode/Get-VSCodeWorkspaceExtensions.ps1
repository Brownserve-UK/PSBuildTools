function Get-VSCodeWorkspaceExtensions
{
    [CmdletBinding()]
    param
    (
        # The path to the repo where spellings should be added
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspacePath
    )
    begin
    {
    }
    process
    {
        Assert-Directory $WorkspacePath -ErrorAction 'stop'
        $RepoVSCodePath = Join-Path $WorkspacePath '.vscode'
        $RepoVSCodeExtensionsPath = Join-Path $RepoVSCodePath 'extensions.json'
        if (Test-Path $RepoVSCodeExtensionsPath)
        {
            Write-Verbose "Getting current extensions list from '$RepoVSCodeExtensionsPath'."
            try
            {
                $CurrentExtensions = Get-Content $RepoVSCodeExtensionsPath -Raw |
                    ConvertFrom-Json -AsHashtable |
                        Select-Object -ExpandProperty 'recommendations'
                if (!$CurrentExtensions)
                {
                    $CurrentExtensions = $null
                }
            }
            catch
            {
                throw "Failed to get current extensions list from '$RepoVSCodeExtensionsPath'.`n$($_.Exception.Message)"
            }
        }
        else
        {
            # It may be expected that the file doesn't exist yet so don't terminate and let the calling command deal with that.
            Write-Error `
                -Exception ([System.IO.FileNotFoundException]::New('Could not find extensions file',$RepoVSCodeExtensionsPath))
            $CurrentExtensions = $null
        }
    }
    end
    {
        if ($CurrentExtensions)
        {
            Return $CurrentExtensions
        }
        else
        {
            return $null
        }
    }
}
