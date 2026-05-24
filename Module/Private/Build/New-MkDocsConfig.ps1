function New-MkDocsConfig
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
            $Template = Get-Content (Join-Path $PSScriptRoot 'templates' 'mkdocs.yml.template') -Raw
        }
        catch
        {
            throw "Failed to import MkDocs config template.`n$($_.Exception.Message)"
        }
    }
    process
    {
        return $Template -replace '###MODULE_NAME###', $ModuleName
    }
    end {}
}
