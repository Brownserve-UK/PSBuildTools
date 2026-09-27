<#
.SYNOPSIS
    Returns the mapping used to migrate a v1 '.brownserve_repository_manifest' (keyed on 'RepositoryType') to
    the v2, component based manifest.
.DESCRIPTION
    Each legacy 'BrownserveRepoProjectType' maps to the set of components (and, where necessary, component
    options) that reproduce that type's generated output.
#>
function Get-BrownserveLegacyRepositoryComponentMapping
{
    [CmdletBinding()]
    param ()
    process
    {
        return @{
            PowerShellModule  = @{
                Components = @('PowerShellModule', 'MkDocs')
            }
            BrownservePSTools = @{
                Components = @('PowerShellModule', 'MkDocs')
                Options    = @{
                    PowerShellModule = @{ UseWorkingCopy = $true; IncludeLicense = $false }
                }
            }
            WebApp            = @{
                Components = @('ContainerImage')
                Options    = @{
                    ContainerImage = @{ Context = '.' }
                }
            }
            RustApp           = @{
                Components = @('RustBinary')
            }
            bsdev             = @{
                Components = @('RustBinary', 'ContainerImage')
                Options    = @{
                    ContainerImage = @{
                        Context                  = 'image'
                        IncludeEnvIgnore          = $false
                        IncludeShellEditorConfig  = $true
                    }
                }
            }
            SkillsRepo        = @{
                Components = @('DirectoryArchive', 'AstroDocs')
                Options    = @{
                    DirectoryArchive = @{ Path = 'skills' }
                }
            }
            Generic           = @{
                Components = @()
            }
        }
    }
}
