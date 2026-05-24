function New-BrownserveGitHubLabelPRWorkflow
{
    [CmdletBinding()]
    param
    (
    )
    begin
    {
        try
        {
            $Template = Get-Content (Join-Path $PSScriptRoot 'templates' 'psmodule_github_label-pr.yaml.template') -Raw
        }
        catch
        {
            throw "Failed to import label-pr workflow template.`n$($_.Exception.Message)"
        }
    }
    process
    {
        return $Template
    }
    end
    {
    }
}
