<#
.SYNOPSIS
    Renders provider-neutral secrets as the lines of a GitHub Actions 'secrets:' block.
.DESCRIPTION
    Looks each secret up in the 'Core' component's 'GitHubActions.Secrets' data, which names the reusable
    workflow's input and the repository secret that feeds it. Secrets are always mapped explicitly, never
    inherited.
#>
function Format-BrownserveGitHubSecret
{
    [CmdletBinding()]
    param
    (
        # The provider-neutral secret names
        [Parameter(Mandatory = $true)]
        [string[]]
        $Secrets,

        # Every known component definition, keyed by name
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ComponentDefinitions,

        # The number of spaces the 'secrets:' line is indented by
        [Parameter(Mandatory = $false)]
        [int]
        $Indent = 4
    )
    process
    {
        $SecretMap = $ComponentDefinitions['Core'].Data.GitHubActions.Secrets
        $Padding = ' ' * $Indent
        $Lines = @("${Padding}secrets:")
        foreach ($Secret in $Secrets)
        {
            if (!$SecretMap.ContainsKey($Secret))
            {
                throw "The secret '$Secret' has no GitHub Actions mapping. Add it to 'GitHubActions.Secrets' in 'Module/Private/Components/Core/component.psd1'."
            }
            $Lines += "$Padding  $($SecretMap[$Secret].Input): `${{ secrets.$($SecretMap[$Secret].Name) }}"
        }
        return $Lines
    }
}
