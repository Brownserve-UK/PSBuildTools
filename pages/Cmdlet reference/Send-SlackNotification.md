---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Send-SlackNotification

## SYNOPSIS

Sends a notification to a given Slack webhook

## SYNTAX

### Default (Default)

```text
Send-SlackNotification [-Message] <String> [-Webhook] <String> [[-Channel] <String>] [-UpperBlocks <Array>]
 [<CommonParameters>]
```

### Attachments

```text
Send-SlackNotification [-Message] <String> [-Webhook] <String> [[-Channel] <String>] [-Colour <String>]
 [-Title <String>] [-UpperBlocks <Array>] [-SubBlocks <Array>] [-Fields <Array>]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will send a message to a given Slack webhook, complex messages are formed using the legacy [attachments](https://api.slack.com/reference/messaging/attachments) method (though limited support for block kit is supported via the `-UpperBlocks` parameter)

## EXAMPLES

### Example 1: Simple message

```powershell
Send-SlackNotification -Message "This is a test" -Webhook "https://mywebhook"
```

Would send the message "This is a test" to the given Slack webhook

### Example 2: More complex message

```powershell
Send-SlackNotification -Message "This is a test" -Webhook "https://mywebhook" -Color "#FF0000" -Title "This is a title"
```

This would send the message "This is a test" to the given Slack webhook, the left hand side of the message would feature a red bar and "This is a title" would be displayed in large text at the top of the message

### Example 3: Custom sections

```powershell
$SubBlocks = @(
    @{                                                                                          
        type = "section"
        fields = @(
            @{ 
                type = "mrkdwn"
                text = "Bottom Left?"
            },
            @{
                type = "mrkdwn"
                text = "Bottom Right?"
            }
        )
    }
)
Send-SlackNotification -Message "This is a test" -Webhook "https://mywebhook" -Color "#FF0000" -Title "This is a title" -SubBlocks $SubBlocks
```

In this example we create a set of nested objects containing some additional fields that we wish to append to the message, these are then passed in to the cmdlet with the `-SubBlocks` parameter

## PARAMETERS

### -Channel

The ID of the channel you wish to post to (e.g. CC64VC954) you get get this from visiting Slack in a Browser and copying it from the URL.  
This parameter is completely optional, if left blank it will use the default channel assigned to the webhook.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Colour

The colour (if any) to use for the notification, it will be displayed down the left hand side of the message.  
The colour should be in hexadecimal format.

```yaml
Type: String
Parameter Sets: Attachments
Aliases: color

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Fields

An optional array of attachment fields to add to the message (max of 3), see https://api.slack.com/reference/messaging/attachments#field_objects for more information.

```yaml
Type: Array
Parameter Sets: Attachments
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Message

The message to be sent

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SubBlocks

Any additional sub-blocks you would like displayed at the end of the message, these need to be formed as an array of hashtable's and are *not* validated in any way by the cmdlet.  

If your message is over 3000 characters in length then SubBlocks cannot be used, please use the `-UpperBlocks` or `-Fields` parameters instead.  

More info can be found at https://api.slack.com/reference/block-kit/blocks

```yaml
Type: Array
Parameter Sets: Attachments
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Title

The title to display above the message (and in any pop-up/push/toast notifications), this is optional.

```yaml
Type: String
Parameter Sets: Attachments
Aliases: Push

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -UpperBlocks

Blocks that appear at the top of the message these need to be formed as an array of hashtable's and are *not* validated in any way by the cmdlet.  

More info can be found at https://api.slack.com/reference/block-kit/blocks

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Webhook

The webhook to post to

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

### System.Array

## OUTPUTS

### System.Object

## NOTES

This cmdlet currently uses the "attachments" method which has now been deprecated by Slack.  
We can't yet switch over to the full block-kit method as it's lacking colour support which we make heavy use of, once that becomes available we can make the switch though some logic tweaking will be required.

## RELATED LINKS
