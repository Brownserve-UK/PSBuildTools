function Send-BuildNotification
{
    [CmdletBinding()]
    param
    (
        # The name of the build that is being reported on.
        [Parameter(
            Mandatory = $false,
            Position = 0
        )]
        [string]
        $BuildName,

        # The status of the build.
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [ValidateSet('Success', 'Fail', 'Information', 'Warning', 'Failure', 'Cancelled')]
        [Alias('Status')]
        [string]
        $BuildStatus,

        # The name of the repo this build belongs to.
        [Parameter(
            Mandatory = $false,
            Position = 2
            )]
        [string]
        $RepoName,

        # An optional branch that the build is running against
        [Parameter(
            Mandatory = $false,
            Position = 3
        )]
        [string]
        $RepoBranch,

        # The webhook URL to send the notification to.
        [Parameter(
            Mandatory = $true,
            Position = 3
        )]
        [string]
        $Webhook,

        # The message to send (optional).
        [Parameter(
            Mandatory = $false, 
            Position = 4
        )]
        [string]
        $Message,

        # The push message to send (optional).
        [Parameter(
            Mandatory = $false,
            Position = 5
        )]
        [string]
        [alias('Push', 'Title')]
        $PushMessage
    )
    
    begin
    {
        if (!$Webhook)
        {
            throw 'No webhook specified.'
        }
        if (!$BuildName)
        {
            try
            {
                $BuildName = Split-Path $MyInvocation.PSCommandPath -Leaf
            }
            catch
            {
                throw 'Failed to get the name of the build programmatically.'
            }
        }
    }
    
    process
    {
        $Fields = @()
        if ($RepoName)
        {
            $Fields += @{
                title = 'Repo:'
                value = "$RepoName"
                short = $true
            }
        }
        if ($BuildName)
        {
            
            $Fields += @{
                title = 'Build:'
                value = "$BuildName"
                short = $true
            }
        }
        if ($RepoBranch)
        {
            $Fields += @{
                title = 'Branch:'
                value = $RepoBranch
                short = $false
            }
        }
        switch -Regex ($BuildStatus.ToLower())
        {
            'success'
            {
                $Colour = '#007C00'
                if (!$PushMessage)
                {
                    $PushMessage = "$BuildName has completed successfully."
                }
                if (!$Message)
                {
                    $Message = "$BuildName has completed successfully."
                }
            }
            'fail'
            {
                $Colour = '#FF0000'
                if (!$PushMessage)
                {
                    $PushMessage = "$BuildName has failed."
                }
                if (!$Message)
                {
                    $Message = "$BuildName has failed."
                }
            }
            'information'
            {
                $Colour = '#00c4ff'
                if (!$PushMessage)
                {
                    $PushMessage = "$BuildName has completed with information."
                }
                if (!$Message)
                {
                    $Message = "$BuildName has completed with information."
                }
            }
            'warning'
            {
                $Colour = '#ffc000'
                if (!$PushMessage)
                {
                    $PushMessage = "$BuildName has completed with a warning."
                }
                if (!$Message)
                {
                    $Message = "$BuildName has completed with a warning."
                }
            }
            'cancelled'
            {
                $Colour = '#808080'
                if (!$PushMessage)
                {
                    $PushMessage = "$BuildName has been cancelled."
                }
                if (!$Message)
                {
                    $Message = "$BuildName has been cancelled."
                }
            }
        }
        # For now we only support sending to Slack.
        try
        {
            Send-SlackNotification `
                -Message $Message `
                -Webhook $Webhook `
                -Colour $Colour `
                -Title $PushMessage `
                -Fields $Fields
        }
        catch
        {
            Write-Error "Failed to send notification.`n$($_.Exception.Message)"
        }
    }
    end
    {
        
    }
}   