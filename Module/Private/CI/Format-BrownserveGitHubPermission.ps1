<#
.SYNOPSIS
    Renders provider-neutral permissions as the lines of a GitHub Actions 'permissions:' block.
.DESCRIPTION
    Looks each permission up in the 'Core' component's 'GitHubActions.PermissionScopes' data and returns the
    'permissions:' line and one indented 'scope: access' line per permission, in the order supplied.
#>
function Format-BrownserveGitHubPermission
{
    [CmdletBinding()]
    param
    (
        # The provider-neutral permission names
        [Parameter(Mandatory = $true)]
        [string[]]
        $Permissions,

        # Every known component definition, keyed by name
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ComponentDefinitions,

        # The number of spaces the 'permissions:' line is indented by
        [Parameter(Mandatory = $false)]
        [int]
        $Indent = 4
    )
    process
    {
        $Scopes = $ComponentDefinitions['Core'].Data.GitHubActions.PermissionScopes
        $Padding = ' ' * $Indent
        $Lines = @("${Padding}permissions:")
        foreach ($Permission in $Permissions)
        {
            if (!$Scopes.ContainsKey($Permission))
            {
                throw "The permission '$Permission' has no GitHub Actions token scope. Add it to 'GitHubActions.PermissionScopes' in 'Module/Private/Components/Core/component.psd1'."
            }
            $Lines += "$Padding  $($Scopes[$Permission].Scope): $($Scopes[$Permission].Access)"
        }
        return $Lines
    }
}
