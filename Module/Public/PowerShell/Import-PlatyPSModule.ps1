function Import-PlatyPSModule
{
    [CmdletBinding()]
    param
    (
        
    )
    
    begin
    {
        <#
            Check the current list of modules to make sure we don't have PlatyPS loaded, if we do then bomb out now.
            Also check to see if we already have PowerShell-YAML loaded, if we do we'll want to keep it loaded so as not to mess with the users environment!
        #>
        $LoadedModules = Get-Module
        if ($LoadedModules.Name -contains 'powershell-yaml')
        {
            throw "Currently the PlatyPS and PowerShell-YAML modules cannot be loaded at the same time due to an assembly incompatibility.`nSee https://github.com/PowerShell/platyPS/issues/592 for more information"
        }
        $PreloadedPlatyPS = $LoadedModules | Where-Object { $_.Name -eq 'PlatyPS' }
    }
    
    process
    {
        try
        {
            # If it's already loaded then don't overwrite whatever the user has loaded!
            if (!$PreloadedPlatyPS)
            {
                # First see if the special Brownserve variable is set, if so attempt to download the version from the repo.
                if ($Global:BrownserveRepoPlatyPSPath)
                {
                    Write-Verbose 'Loading local version of PlatyPS'
                    Import-Module $Global:BrownserveRepoPlatyPSPath `
                        -Force `
                        -ErrorAction 'Stop' `
                        -Verbose:$false
                }
                # Otherwise attempt to load any version installed on the system
                else
                {
                    Write-Verbose 'Loading system version of PlatyPS'
                    Import-Module 'PlatyPS' `
                        -Force `
                        -ErrorAction 'Stop' `
                        -Verbose:$false
                }
            }
        }
        catch
        {
            $ErrorMessage = 'Failed to load PlatyPS module.'
            if (!$Global:BrownserveRepoPlatyPSPath)
            {
                $ErrorMessage += "`nThe '`$Global:BrownserveRepoPlatyPSPath' variable has not been set and PowerShell failed to load any versions installed locally."
            }
            throw "$ErrorMessage.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        if ($PreloadedPlatyPS)
        {
            return $PreloadedPlatyPS
        }
        else
        {
            return $null
        }
    }
}