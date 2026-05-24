function New-VSCodeDevcontainer
{
    [CmdletBinding()]
    param
    (
        # The source of the devcontainer
        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $DevcontainerTemplateDirectory = (Join-Path $PSScriptRoot -ChildPath 'devcontainer'),

        # The dockerfile to use
        [Parameter(Mandatory = $false, Position = 2)]
        [string]
        $Dockerfile = 'Dockerfile_Generic',

        # Required VSCode extensions
        [Parameter(Mandatory = $false)]
        [string[]]
        $RequiredExtensions
    )
    # Make sure the snippet path is valid
    if (!(Test-Path $DevcontainerTemplateDirectory))
    {
        throw "$DevcontainerTemplateDirectory does not exist"
    }

    try
    {
        $DockerfileContent = Get-BrownserveContent `
            -Path (Join-Path $DevcontainerTemplateDirectory $Dockerfile) `
            -ErrorAction 'Stop'
    }
    catch
    {
        throw "Failed to get Dockerfile template '$Dockerfile'"
    }

    try
    {
        $DevcontainerObject = [ordered]@{
            name = 'Ubuntu'
            build = [ordered]@{
                args = @{
                    VARIANT = 'focal'
                }
                dockerfile = "Dockerfile"
            }
            customizations = [ordered]@{
                vscode = [ordered]@{
                    extensions = @()
                    settings = [ordered]@{}
                }
            }
            remoteUser = 'vscode'
        }

        if ($RequiredExtensions)
        {
            $DevcontainerObject.customizations.vscode.extensions = $RequiredExtensions
        }

        # TODO: Set default shell: https://stackoverflow.com/a/70796646/10843454

        $DevcontainerJSON = $DevcontainerObject | ConvertTo-Json -Depth 100 | Format-BrownserveContent
    }
    catch
    {
        throw "Failed to create devcontainer.json.`n$($_.Exception.Message)"
    }

    [PSCustomObject]@{
        devcontainer = $DevcontainerJSON
        Dockerfile = $DockerfileContent
    }
}
