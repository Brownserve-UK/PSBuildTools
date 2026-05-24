function New-SPDXLicense
{
    [CmdletBinding()]
    param
    (
        # The type of license to use
        [Parameter(
            Mandatory = $true
        )]
        [ValidateSet('MIT')]
        [string]
        $LicenseType,

        # The name of the company or individual that owns the license
        [Parameter(
            Mandatory = $true
        )]
        [string]
        $Owner,

        # The year the license was created
        [Parameter(
            Mandatory = $false
        )]
        [int]
        $Year = (Get-Date).Year,

        # The URI to use to grab the license information
        [Parameter(
            Mandatory = $false,
            DontShow
        )]
        [uri]
        $Uri = 'https://raw.githubusercontent.com/spdx/license-list-data/main/json/licenses.json'
    )
    begin
    {
        $License = $null
    }
    process
    {
        try
        {
            # Search the licenses for the license type
            $LicenseIDs = Invoke-RestMethod `
                -Method 'Get' `
                -Uri $Uri `
                -ErrorAction 'stop' |
                Select-Object -ExpandProperty licenses |
                    Where-Object { $_.licenseID -eq $LicenseType }
            if (!$LicenseIDs)
            {
                throw "No license found for $LicenseType"
            }
            # Grab the full license details
            $LicenseDetails = Invoke-RestMethod `
                -Method 'Get' `
                -Uri $LicenseIDs[0].detailsUrl `
                -ErrorAction 'stop'
            if (!$LicenseDetails)
            {
                throw "No license details returned for $LicenseType"
            }
            if ($LicenseDetails.isDeprecatedLicenseId)
            {
                Write-Warning "The license $LicenseType is deprecated"
            }
        }
        catch
        {
            throw "Failed to get SPDX licenses.`n$($_.Exception.Message)"
        }

        switch ($LicenseType)
        {
            'MIT'
            {
                $License = $LicenseDetails.licenseText -replace '<year>', $Year -replace '<copyright holders>', $Owner
            }
            Default
            {
                throw "License type $LicenseType not supported"
            }
        }
    }
    end
    {
        if ($License)
        {
            return $License
        }
        else
        {
            return $null
        }
    }
}
