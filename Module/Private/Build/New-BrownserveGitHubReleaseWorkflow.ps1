function New-BrownserveGitHubReleaseWorkflow
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName,

        # The GitHub repository name, if different from the module name
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName = $ModuleName
    )
    begin
    {
        try
        {
            $Template = Get-Content (Join-Path $PSScriptRoot 'templates' 'psmodule_github_release.yaml.template') -Raw
        }
        catch
        {
            throw "Failed to import release workflow template.`n$($_.Exception.Message)"
        }
    }
    process
    {
        return $Template -replace '###REPO_NAME###', $RepoName
    }
    end
    {
    }
}
