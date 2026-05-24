function New-MkDocsRequirements
{
    [CmdletBinding()]
    param()
    process
    {
        return @'
mkdocs-material==9.7.6
mkdocs-awesome-pages-plugin==2.10.1
'@
    }
}
