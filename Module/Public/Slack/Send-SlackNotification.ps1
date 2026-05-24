function Send-SlackNotification
{
    [CmdletBinding(
        DefaultParameterSetName = "Default"
    )]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]
        $Message,

        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )] 
        [string]
        $Webhook,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 3
        )]
        [string]
        $Channel,
    
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Attachments"
        )]
        [string]
        [Alias('color')]
        $Colour, 
    
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Attachments"
        )]
        [Alias('Push')]
        [string]
        $Title,

        [Parameter(
            Mandatory = $false, 
            ValueFromPipelineByPropertyName = $true
            )]
        [array]
        $UpperBlocks,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Attachments"
        )]
        [array]
        $SubBlocks,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Attachments"
        )]
        [array]
        $Fields
    )

    if ($Title.Length -gt 75)
    {
        throw "Title must be 75 characters or less"
    }

    if ($Fields -and $SubBlocks)
    {
        throw "You cannot specify both -Fields and SubBlocks"
    }

    # Let's initialize an empty hash table that we'll use to build up the JSON payload
    # By default we set the "text" field to the $message variable so we always have something to send
    $SlackBody = @{
        text        = $Message
        blocks      = @()
        attachments = @(
            @{
                blocks = @(
                )
            }
        )
    }

    if ($Channel)
    {
        $SlackBody.Add('channel', $Channel)
    }

    if ($Colour)
    {
        if ($Colour -notmatch '#[0-9A-Fa-f]{6}')
        {
            throw "Colour must match the hexadecimal colour format. (e.g #FF1234)"
        }
        $SlackBody.attachments[0].Add('color', $Colour)
    }

    # If we've got any "attachments" then we need to make sure our message is set in the "attachments" section
    If ($Title -or $Colour)
    {
        # Make sure the "text" param is blanked out otherwise it really messes things up :(
        $SlackBody.text = ""

        # Add a fallback message to the attachment - this affects things like pop-up's/toasts
        $SlackBody.attachments[0].Add('fallback', $Title)

        # If the message is longer than the max length we'll need to send it as raw text to the attachment instead.
        try
        {
            $MessageLength = ($Message | ConvertTo-Json).Length
        }
        catch
        {
            # Ignore errors
        }
        if (!$MessageLength)
        {
            Write-Verbose "Failed to determine JSON length of message, falling back to legacy method"
            $MessageLength = $Message.Length
        }
        if ($MessageLength -lt 3000 -and (!$Fields))
        {
            # Build up a message object, but add it later
            $MessageObject = @{
                type = 'section'
                text = @{
                    type = 'mrkdwn'
                    text = $Message
                }
            }
        }
        else
        {
            Write-Verbose "Message over 3000 characters or -Fields specified, falling back to legacy method"
            $SlackBody.attachments[0].Add('text', $Message)
            # We need to tell Slack that the text is a "mrkdwn" type
            $SlackBody.attachments[0].Add('mrkdwn_in', @('text'))
        }
    }

    if ($Title)
    {
        # If we're using the "attachments" for our main text then we need to add the title to the attachment instead of the blocks
        if ($SlackBody.attachments[0].text)
        {
            $SlackBody.attachments[0].Add('title', $Title)
        }
        else
        {
            # Build up the "title" object and add it to the body
            $TitleObject = @{
                type = 'header'
                text = @{
                    type  = 'plain_text'
                    text  = $Title
                    emoji = $true
                }
            }
            $SlackBody.attachments[0].blocks += $TitleObject
        }
    }

    # We need to add the message object _after_ the title otherwise things look wrong 😂
    if ($MessageObject)
    {
        $SlackBody.attachments[0].blocks += $MessageObject
    }

    # If we've got any sub-blocks then add them at the end of the message
    if ($SubBlocks)
    {
        if ($SlackBody.attachments[0].text)
        {
            Write-Warning "Cannot use SubBlocks due to length of main message, they will be ignored.`nTry using -UpperBlocks or -Fields instead"
            $SubBlocks = $null
        }
        if ($SubBlocks.count -gt 100)
        {
            Write-Warning "Cannot use SubBlocks due to too many blocks, they will be ignored. (Maximum 100 blocks)"
            $SubBlocks = $null
        }
        if ($SubBlocks.fields)
        {
            if ($SubBlocks.fields.count -gt 10)
            {
                Write-Warning "Cannot use SubBlocks with fields that contain more than 10 items, they will be ignored."
                $SubBlocks = $null
            }
        }
        if ($SubBlocks)
        {
            $SubBlocks | ForEach-Object {
                $SlackBody.attachments[0].blocks += $_
            }
        }
    }

        # If we've got any upper-blocks then add them in
        if ($UpperBlocks)
        {
            if ($UpperBlocks.count -gt 100)
            {
                Write-Warning "Cannot use SubBlocks due to too many blocks, they will be ignored. (Maximum 100 blocks)"
                $UpperBlocks = $null
            }
            if ($UpperBlocks.fields)
            {
                if ($UpperBlocks.fields.count -gt 10)
                {
                    Write-Warning "Cannot use SubBlocks with fields that contain more than 10 items, they will be ignored."
                    $UpperBlocks = $null
                }
            }
            if ($UpperBlocks)
            {
                $UpperBlocks | ForEach-Object {
                    $SlackBody.blocks += $_
                }
            }
        }

        # If we've got any fields then add them in
        if ($Fields)
        {
            # 'fields' and 'blocks' cannot be used together, so remove blocks if we've got them
            $SlackBody.attachments[0].remove('blocks')
            $SlackBody.attachments[0].Add('fields', @())
            if ($Fields.Count -gt 3)
            {
                Write-Warning "Cannot use Fields with more than 3 items, they will be ignored."
                $Fields = $null
            }
            if ($Fields)
            {
                $Fields | ForEach-Object {
                    $SlackBody.attachments[0].fields += $_
                }
            }
        }

    # Convert with a reasonable depth, we have a lot of nested objects!
    $ConvertedBody = $SlackBody | ConvertTo-Json -Depth 10

    Write-Debug $ConvertedBody

    try
    {
        Invoke-RestMethod -Uri $Webhook -Method Post -Body $ConvertedBody -ErrorAction Stop
    }
    catch
    {
        # We can't control what a user enters in the SubBlocks parameter, so try to warn them if they've got something wrong
        $AdditionalError = ""
        if ($SubBlocks)
        {
            $AdditionalError += "`nYou are using SubBlocks, it's possible that your SubBlocks are malformed, try removing them and running the command again."
        }
        if ($UpperBlocks)
        {
            $AdditionalError += "`nYou are using UpperBlocks, it's possible that your UpperBlocks are malformed, try removing them and running the command again."
        }
        if ($Fields)
        {
            $AdditionalError += "`nYou are using Fields, it's possible that your Fields are malformed, try removing them and running the command again."
        }
        Write-Error "Failed to send Slack notification.$AdditionalError.`n$($_.Exception.Message)"
    }
}
