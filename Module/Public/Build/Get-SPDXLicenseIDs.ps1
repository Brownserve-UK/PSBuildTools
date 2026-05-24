function Get-SPDXLicenseIDs
{
    [CmdletBinding()]
    param
    (
        # The uri to use to grab the ID's
        [Parameter(Mandatory = $false)]
        [uri]
        $Uri = 'https://raw.githubusercontent.com/spdx/license-list-data/main/json/licenses.json'    
    )
    
    begin
    {
        
    }
    
    process
    {
        try
        {
            $JSon = Invoke-WebRequest `
                -Uri $Uri `
                -Method 'Get' `
                -ErrorAction 'stop' | 
                    Select-Object -ExpandProperty Content |
                        ConvertFrom-Json
            $IDs = $JSon.licenses | Select-Object -ExpandProperty licenseID
            if (!$IDs)
            {
                Write-Error "No licences found!"
            }
        }
        catch
        {
            throw "Failed to get SPDX licences.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        if ($IDs)
        {
            return $IDs
        }
    }
}