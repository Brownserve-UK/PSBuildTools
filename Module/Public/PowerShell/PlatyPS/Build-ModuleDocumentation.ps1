function Build-ModuleDocumentation
{
    [CmdletBinding()]
    param
    (
        # The name of the module to have the help created for
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName,

        # The path to the module
        [Parameter(Mandatory = $true)]
        [string]
        $ModulePath,

        # The directory that the help should be stored in
        [Parameter(Mandatory = $true)]
        [string]
        $DocumentationPath,

        # If set forces a reload of the module your building docs for if it's already loaded
        [Parameter(Mandatory = $false)]
        [switch]
        $ReloadModule,

        # If set parameters marked as 'DontShow' will be included
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeDontShow,

        # The GUID of the module (if desired)
        [Parameter(Mandatory = $false)]
        [guid]
        $ModuleGUID,

        # The help version number to use
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [System.Management.Automation.SemanticVersion]
        $HelpVersion,

        # If set, cmdlet docs are written directly to DocumentationPath (no module-named subdirectory).
        # The module page is written as Commands.md instead of {ModuleName}.md.
        [Parameter(Mandatory = $false)]
        [switch]
        $NoModuleSubdirectory
    )
    begin
    {
        $FilesToWrite = @()
        # Ensure the documentation directory is indeed a dir
        Assert-Directory $DocumentationPath -ErrorAction 'Stop'

        <#
            Check if the module is already loaded, this is important as if we load the module then we should
            unload it at the end of the cmdlet.
            This is due to incompatibilities between platyPS and powershell-yaml.
            https://github.com/PowerShell/platyPS/issues/592
        #>
        $PreloadedPlatyPS = Import-PlatyPSModule -ErrorAction 'Stop'

        $Return = @()
    }
    process
    {
        # We'll encapsulate everything in one big try/catch block so we can unload the module if we have to.
        # Once we can run platyPS and powershell-yaml side-by-side then we can refactor this hot mess.
        try
        {
            $ModuleDirectory = Get-Item (Split-Path $ModulePath) | Convert-Path

            # Check if the module is already loaded
            $ModuleLoaded = Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue'
            # Sometimes we may want to unload the module and reload it, especially if we've been working on changes as this ensures anything new will be picked up.
            if ($ModuleLoaded -and $ReloadModule)
            {
                $ErrorStep = "Unable to unload module '$ModuleName'"
                Remove-Module $ModuleName -Force -ErrorAction 'Stop'
            }
            if (!$ModuleLoaded -or $ReloadModule)
            {
                $ErrorStep = "Failed to import module '$ModuleName' from $ModulePath."
                Import-Module -Name $ModulePath -Force -Global -ErrorAction 'Stop' -Verbose:$false
            }
            $ModuleDetails = Get-Module -Name $ModuleName
            # We no longer generate the help version here, we rely on it being passed in.
            # If we need to bring this back in the future we can make a param like -GenerateVersion or something
            # if (!$HelpVersion)
            # {
            #     $HelpVersion = ($ModuleDetails | Select-Object -ExpandProperty Version).ToString()
            #     if ($ModuleDetails.PrivateData.PSData.Prerelease)
            #     {
            #         $HelpVersion = "$($HelpVersion.Value)-$($ModuleDetails.PrivateData.PSData.Prerelease)"
            #     }
            # }
            if (!$ModuleGUID)
            {
                $ModuleGUID = $ModuleDetails.Guid.Guid
            }
            else
            {
                if ($ModuleGUID -ne $ModuleDetails.Guid.Guid)
                {
                    throw "Module GUID '$ModuleGUID' doesn't match the GUID of the module '$($ModuleDetails.Guid.Guid)'."
                }
            }
            $ModuleDescription = $ModuleDetails | Select-Object -ExpandProperty Description

            # TODO: The below can be revisited when we've got updatable help figured out
            # # Lets see if the module is part of a git repo, and if it is then try to work out the URL for the docs would be
            # $ModuleRepoURL = Get-GitRemoteOriginURL $DocumentationPath -ErrorAction 'SilentlyContinue' | ConvertTo-HTTPSRepoURL -ErrorAction 'SilentlyContinue'
            # if ($ModuleRepoURL)
            # {
            #     $HelpDocsLink = $ModuleRepoURL + "/tree/v$HelpVersion/$DocumentationPath/$ModuleName"
            # }

            if ($NoModuleSubdirectory)
            {
                $PublicCmdletDocPath = $DocumentationPath
                $ModulePagePath = Join-Path $DocumentationPath 'Commands.md'
            }
            else
            {
                # Create a directory with the name of module to be used to store the docs
                $ModuleDocumentationDirectory = Join-Path $DocumentationPath $ModuleName
                if (!(Test-Path $ModuleDocumentationDirectory))
                {
                    $ErrorStep = 'Failed to create module documentation directory'
                    New-Item $ModuleDocumentationDirectory -ItemType Directory -ErrorAction 'Stop' | Out-Null
                }
                $PublicCmdletDocPath = $ModuleDocumentationDirectory
                $ModulePagePath = Join-Path $DocumentationPath "$($ModuleName).md"
            }

            $PlatyParams = @{
                AlphabeticParamsOrder = $true
                ModulePagePath        = $ModulePagePath
            }
            if (!$IncludeDontShow)
            {
                $PlatyParams.Add('ExcludeDontShow', $true)
            }

            # Check for the presence of either a module page or existing markdown documentation
            # If either exist then we should run the update command instead of the new command.
            $ExistingDocs = Get-ChildItem `
                -Path $PublicCmdletDocPath `
                -Filter '*.md' `
                -Recurse |
                    Where-Object { $_.FullName -ne $ModulePagePath }
            $ExistingModulePage = Get-Item $ModulePagePath -ErrorAction 'SilentlyContinue'

            if (!$ExistingDocs -and !$ExistingModulePage)
            {
                $NewDocsParams = $PlatyParams
                $NewDocsParams.Add('OutputFolder', $PublicCmdletDocPath)
                $NewDocsParams.Add('Module', $ModuleName)
                $NewDocsParams.Add('WithModulePage', $true)
                if ($HelpVersion)
                {
                    $NewDocsParams.Add('HelpVersion', $HelpVersion)
                }
                if ($HelpDocsLink)
                {
                    $NewDocsParams.Add('FWLink', $HelpDocsLink)
                }
                $ErrorStep = "Failed to build new module documentation for $ModuleName."
                # Mute warnings as cmdlets that are not yet documented will cause complaints 🙄
                # Out-Null as we get a bunch of File returns from what I assume is New-Item
                New-MarkdownHelp @NewDocsParams -ErrorAction 'Stop' -WarningAction 'SilentlyContinue' | Out-Null
            }
            else
            {
                $UpdateDocsParams = $PlatyParams
                $UpdateDocsParams.Add('Path', $PublicCmdletDocPath)
                $UpdateDocsParams.Add('RefreshModulePage', $true)
                $UpdateDocsParams.Add('UpdateInputOutput', $true)
                $UpdateDocsParams.Add('Force', $true) # This is a poorly named parameter it actually just deletes cmdlets that have been removed.
                # For some reason we get a lot of warnings when using the update cmdlet that make no sense, so just mute them for now.
                # Out-Null as we get a bunch of File returns from what I assume is New-Item for any new documentation
                $ErrorStep = 'Failed to update module documentation'
                Update-MarkdownHelpModule @UpdateDocsParams -ErrorAction 'Stop' -WarningAction 'SilentlyContinue' | Out-Null
            }
            <#
                Here be dragons.
                As awesome as platyPS is, it has quite a few quirks that we need to work around.
                (at least until the rewrite is done and v2 is released)
                See the notes below and the individual cmdlets for more information on what we're doing here.
            #>

            <#
                First up - deal with the module page which needs a bit of molding to get it into shape.
                We've split this out into a separate cmdlet as it's a bit of a beast and we want to keep things
                easy to read and maintain.
            #>

            # To save having a bunch of calls to get/set content we'll just get it once and pass it around to be
            # modified as needed.
            $ModulePageContent = Get-BrownserveContent -Path $ModulePagePath -ErrorAction 'Stop'

            # When cmdlets are in the same directory as the module page, PlatyPS already generates
            # correct bare-filename links so no adjustment is needed.
            # However, when cmdlet documentation is in a subdirectory, we need to update the links in the module page to point to the correct location.
            if (!$NoModuleSubdirectory)
            {
                $ModulePageContent = Update-PlatyPSModulePageLinks `
                    -CmdletDocumentationPath $PublicCmdletDocPath `
                    -ModulePageContent $ModulePageContent `
                    -ErrorAction 'Stop'
            }

            # If we've passed in a GUID for the module then update the module page with that.
            if ($ModuleGUID)
            {
                $ModulePageContent = Update-PlatyPSModulePageGUID `
                    -ModuleGUID $ModuleGUID `
                    -ModulePageContent $ModulePageContent `
                    -ErrorAction 'Stop'
            }
            <#
                We only update the help version number if it has been passed in
                this is mostly because it's handled by our build pipelines so we'll rarely (if ever) need to
                update it manually.
            #>
            if ($HelpVersion)
            {
                $ModulePageContent = Update-PlatyPSModulePageHelpVersion `
                    -HelpVersion $HelpVersion `
                    -ModulePageContent $ModulePageContent `
                    -ErrorAction 'Stop'
            }

            # If we've passed in a module description then update the module page with that.
            if ($ModuleDescription)
            {
                $ModulePageContent = Update-PlatyPSModulePageDescription `
                    -ModuleDescription $ModuleDescription `
                    -ModulePageContent $ModulePageContent `
                    -ErrorAction 'Stop'
            }

            $ErrorStep = 'Failed to format module page content.'

            <#
                PlatyPS tends to format the markdown files incorrectly and breaks Markdownlint,
                We've got a rudimentary formatter that we can use to fix things up.
                We then pipe it through Format-BrownserveContent to ensure we maintain line endings and the correct use
                of whitespace.
            #>
            $FormattedModulePageMarkdown = Format-Markdown `
                -Markdown $ModulePageContent.Content `
                -ErrorAction 'Stop' |
                    Format-BrownserveContent |
                        Select-Object -ExpandProperty Content
            $ModulePageContent.Content = $FormattedModulePageMarkdown

            $FilesToWrite += $ModulePageContent

            $ErrorStep = 'Failed to process cmdlet documentation.'

            # Get the paths to all the markdown files in the public cmdlet directory
            $MarkdownDocs = Get-ChildItem `
                -Path $PublicCmdletDocPath `
                -Filter '*.md' `
                -Recurse `
                -ErrorAction 'Stop' |
                    Where-Object { $_.FullName -ne $ModulePagePath } |
                        Select-Object -ExpandProperty FullName

            <#
                Now we need to fix the documentation for each cmdlet.
            #>
            $ErrorStep = 'Failed to format cmdlet documentation.'

            $MarkdownDocs | ForEach-Object {
                $CmdletMarkdownContent = Get-BrownserveContent -Path $_ -ErrorAction 'Stop'

                <#
                    Due to this issue: https://github.com/PowerShell/platyPS/issues/595
                    We need to remove the "-ProgressAction" common parameter from the each cmdlets documentation and
                    add it to the list of common parameters at the end of the documentation.
                #>
                $CmdletMarkdownContent = Remove-PlatyPSCommonParameter `
                    -Content $CmdletMarkdownContent `
                    -ErrorAction 'Stop'
                $CmdletMarkdownContent = Add-PlatyPSCommonParameter `
                    -Content $CmdletMarkdownContent `
                    -ErrorAction 'Stop'

                <#
                    Fix the formatting of the markdown content.
                #>
                $FormattedCmdletMarkdown = Format-Markdown `
                    -Markdown $CmdletMarkdownContent.Content `
                    -ErrorAction 'Stop' |
                        Format-BrownserveContent |
                            Select-Object -ExpandProperty Content

                $CmdletMarkdownContent.Content = $FormattedCmdletMarkdown
                $FilesToWrite += $CmdletMarkdownContent
            }

            if ($FilesToWrite)
            {
                <#
                    Write the files to disk and ensure they have LF line endings.
                #>
                $ErrorStep = 'Failed to write documentation files.'
                $FilesToWrite | Set-BrownserveContent -ErrorAction 'Stop' -LineEnding 'LF'
            }

            # Create some sensible return so that we can pipe it into a cmdlet to update the MALM
            $Return += [pscustomobject]@{
                ModuleDirectory   = $ModuleDirectory
                HelpLanguage      = 'en-US' # Hardcoded as we only support the one atm
                DocumentationPath = ($PublicCmdletDocPath | Convert-Path) # Only the public cmdlets need to be documented
            }
        }
        catch
        {
            $ErrorMessage = 'Failed to build module documentation.'
            if ($ErrorStep)
            {
                $ErrorMessage += "`n$ErrorStep"
            }
            $ErrorMessage += "`n$($_.Exception.Message)"
            throw $ErrorMessage
        }
        finally
        {
            <#
                If we've loaded platyPS as part of this cmdlet then chances are we're going to want to un-load it
                This is due to https://github.com/PowerShell/platyPS/issues/592 and the fact we make use of powershell-yaml in places too
            #>
            if (!$PreloadedPlatyPS)
            {
                Write-Verbose 'Unloading PlatyPS module.'
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
        if ($Return -ne @())
        {
            return $Return
        }
        else
        {
            return $null
        }
    }
}
