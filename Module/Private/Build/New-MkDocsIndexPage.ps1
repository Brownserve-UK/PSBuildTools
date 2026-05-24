function New-MkDocsIndexPage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName
    )
    begin
    {
        try
        {
            $Template = Get-Content (Join-Path $PSScriptRoot 'templates' 'mkdocs_index.md.template') -Raw
        }
        catch
        {
            throw "Failed to import MkDocs index page template.`n$($_.Exception.Message)"
        }
    }
    process
    {
        return $Template -replace '###MODULE_NAME###', $ModuleName
    }
    end {}
}
