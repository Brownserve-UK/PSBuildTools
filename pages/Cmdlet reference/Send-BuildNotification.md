---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Send-BuildNotification

## SYNOPSIS

Sends a standard Brownserve build notification.

## SYNTAX

```text
Send-BuildNotification [[-BuildName] <String>] [-BuildStatus] <String> [[-RepoName] <String>]
 [[-RepoBranch] <String>] [-Webhook] <String> [[-Message] <String>] [[-PushMessage] <String>]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will send a standard Brownserve build notification to our build channel.  
This cmdlet is largely useless outside of Brownserve workflows

## EXAMPLES

### Example 1

```powershell
Send-BuildNotification `
    -Webhook $Webhook `
    -Status 'success'
```

This would send a `success` message to the given webhook.

## PARAMETERS

### -BuildName

The name of the build, by default the cmdlet will try to work this out by looking at the calling process but this is not always successful.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BuildStatus

The status of the build.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Status
Accepted values: Success, Fail, Information, Warning, Failure, Cancelled

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Message

The message to be sent, if none is specified a generic one will be sent depending on the outcome of the build

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PushMessage

The title of the notification, if none is specified a generic one will be used depending on the outcome of the build

```yaml
Type: String
Parameter Sets: (All)
Aliases: Push, Title

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RepoBranch

An optional branch that the build is currently running against

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RepoName

An optional repo name the build is currently running against

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Webhook

The webhook to send the notification to, at present only Slack webhooks are supported

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
