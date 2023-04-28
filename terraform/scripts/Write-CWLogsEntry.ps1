 Param (
	[Parameter(Mandatory=$true)][string] $LogGroupName,
	[Parameter(Mandatory=$true)][string] $LogStreamName,
	[Parameter(Mandatory=$true)][string] $LogString
 )

  #Determine if the LogGroup Exists
  If (-Not (Get-CWLLogGroup -LogGroupNamePrefix $LogGroupName)){
	New-CWLLogGroup -LogGroupName $logGroupName
	#Since the loggroup does not exist, we know the logstream does not exist either
	$CWLSParam = @{
	  LogGroupName = $logGroupName
	  LogStreamName = $logStreamName
	}
	New-CWLLogStream @CWLSParam
  }
  #Determine if the LogStream Exists
  If (-Not (Get-CWLLogStream -LogGroupName $logGroupName -LogStreamName $LogStreamName)){
	$CWLSParam = @{
	  LogGroupName = $logGroupName
	  LogStreamName = $logStreamName
	}
	New-CWLLogStream @CWLSParam 
  }

  $logEntry = New-Object -TypeName 'Amazon.CloudWatchLogs.Model.InputLogEvent'
  $logEntry.Message = $LogString
  $logEntry.Timestamp = (Get-Date).ToUniversalTime()
  #Get the next sequence token
  $SequenceToken = (Get-CWLLogStream -LogGroupName $LogGroupName -LogStreamNamePrefix $logStreamName).UploadSequenceToken
  
  #There will be no $SequenceToken when a new Stream is created to we adjust the parameters for this          
  if($SequenceToken){
	$CWLEParam = @{
	  LogEvent      = $logEntry
	  LogGroupName  = $logGroupName
	  LogStreamName = $logStreamName
	  SequenceToken = $SequenceToken
	}
	Write-CWLLogEvent @CWLEParam 
  }else{
	$CWLEParam = @{
	  LogEvent      = $logEntry
	  LogGroupName  = $logGroupName
	  LogStreamName = $logStreamName
	}
	Write-CWLLogEvent @CWLEParam 
  }