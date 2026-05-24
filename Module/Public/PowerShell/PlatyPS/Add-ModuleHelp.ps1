function Add-ModuleHelp
{
    [CmdletBinding()]
    param
    (
        # The path to the directory where the module lives
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]
        $ModuleDirectory,

        # The language that the help is written in
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]
        $HelpLanguage = 'en-US',

        # The path to the documentation that will generate the help file
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]
        $DocumentationPath
    )
    
    begin
    {
        # Ensure the documentation directory is indeed a dir
        Assert-Directory $DocumentationPath -ErrorAction 'Stop'
        Assert-Directory $ModuleDirectory -ErrorAction 'Stop'
        # First we check if the module is already loaded
        $PreloadedPlatyPS = Import-PlatyPSModule -ErrorAction 'Stop'
    }
    
    process
    {

        <#
            Again until a version of platyPS exists that isn't broken and also allows us to load powershell-yaml alongside it
            We need to have one big try/catch block
        #>

        try
        {
            $ModuleDirIsModuleCheck = Get-ChildItem $ModuleDirectory -Recurse | Where-Object { ($_.Name -like '*.psm1') -or { $_.Name -like '*.psd1' } }
            if (!$ModuleDirIsModuleCheck)
            {
                throw "No valid modules could be found in '$ModuleDirectory'"
            }
            
            $HelpPath = Join-Path $ModuleDirectory $HelpLanguage
            if (!(Test-Path $HelpPath))
            {
                New-Item $HelpPath -ItemType Directory -ErrorAction 'Stop'
                throw "Failed to created $HelpPath.`n$($_.Exception.Message)"
            }

            New-ExternalHelp `
                -Path $DocumentationPath `
                -OutputPath $HelpPath `
                -Force `
                -ErrorAction 'Stop'

        }
        catch
        {
            throw "Failed to create external help.`n$($_.Exception.Message)"
        }
        finally
        {
            <# 
                If we've loaded platyPS as part of this cmdlet then chances are we're going to want to un-load it
                This is due to https://github.com/PowerShell/platyPS/issues/592 and the fact we make use of powershell-yaml in places too
            #>
            if (!$PreloadedPlatyPS)
            {
                Write-Verbose "Unloading PlatyPS module."
                Remove-Module 'platyPS' -Force -ErrorAction 'SilentlyContinue'
                if ((Get-Module 'platyPS'))
                {
                    Write-Error 'Failed to unload platyPS module.'
                }
            }
        }
    }
    
    end
    {
        
    }
}