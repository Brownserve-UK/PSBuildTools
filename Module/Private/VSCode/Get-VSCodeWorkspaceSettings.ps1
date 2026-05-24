function Get-VSCodeWorkspaceSettings
{
    [CmdletBinding()]
    param
    (
        # The path to the repo
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
        $RepoVSCodeSettingsPath = Join-Path $RepoVSCodePath 'settings.json'

        if (Test-Path $RepoVSCodeSettingsPath)
        {
            Write-Verbose "Getting VSCode settings from '$RepoVSCodeSettingsPath'."
            try
            {
                $CurrentSettings = Get-Content $RepoVSCodeSettingsPath -Raw | ConvertFrom-Json -AsHashtable
                if (!$CurrentSettings)
                {
                    $CurrentSettings = $null
                }
            }
            catch
            {
                throw "Failed to import current VSCode settings from '$RepoVSCodeSettingsPath'.`n$($_.Exception.Message)"
            }
        }
        else
        {
            # Don't raise a terminating error, it might be expected - let the calling command work out what to do
            Write-Error `
                -Exception ([BrownserveFileNotFound]::New('Failed to find settings file',$RepoVSCodeSettingsPath))
            $CurrentSettings = $null
        }
    }
    end
    {
        if ($CurrentSettings)
        {
            return $CurrentSettings
        }
        else
        {
            return $null
        }
    }
}
