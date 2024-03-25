param (
    [string]$ProcessName,
    [int]$MaxDurationInSeconds = 60,
    [string]$FolderPath = $null,
    [string]$FilePath = $null,
    [string]$ShouldTakeScreenshot = "False",
    [string]$ShouldDebug = "False"
)






$wrapperScriptBlock = {
param (
    [string]$ProcessName,
    [int]$MaxDurationInSeconds,
    [string]$FolderPath = $null,
    [string]$FilePath = $null,
    [string]$ShouldTakeScreenshot = "False",
    [string]$ShouldDebug = "False"
)


#Delete a file if the file exists
function DeleteAFile {
    param (
        [string]$fileToDelete
    )

    if (($fileToDelete) -and (Test-Path $fileToDelete -PathType Leaf)) {
        # File exists, delete it
        Remove-Item $fileToDelete -Force
        Write-Host "File deleted: $fileToDelete"
    } else {
        Write-Host "File does not exist: $fileToDelete"
    }
}


#Take screenshot function : Simply takes the a screenshot of machine screen and saves it in the png file location specified function.
function TakeAScreenshot {
# Take screenshot function : Simply takes the a screenshot of machine screen and saves it in the png file location specified function
    param (
        [string]$ScreenshotFilePath
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $bounds = $screen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)

    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)

    $bitmap.Save($ScreenshotFilePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

#Write To Debug Log file : Simply writes to a log file in a specified location.
function WriteToDebugLog {
#Write To Debug Log file : Simply writes to a log file in a specified location.
    param (
        [string]$Message,
        [string]$LockFilePath,
        [string]$LogFilePath,
        [string]$ShouldDebug
    )
    if ($ShouldDebug -eq "True") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] $Message"

        # Wait for the lock file to be released (deleted)
        while (Test-Path $LockFilePath) {
            Start-Sleep -Milliseconds 100
        }

        # Create the lock file
        New-Item -Path $LockFilePath -ItemType File -Force > $null

        # Write the log entry
        Add-Content -Path $LogFilePath -Value $logEntry

        # Release the lock (delete the lock file)
        Remove-Item -Path $LockFilePath -Force -ErrorAction SilentlyContinue
}
}


#Kill process function : Simply kills a process by name all you have to do is call the function and pass in the process name parameter.
function KillAProcessByName {
# Kill process function : Simply kills a process by name all you have to do is call the function and pass in the process name parameter
    param (
        [string]$ProcessName
    )
    try {
        #Try to kill process
        $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        Write-Host "Killing process $($process.Name) with ID $($process.Id)..."
        Stop-Process -Id $process.Id -Force
        Write-Host "Process killed successfully."
    }
    catch {
        Write-Host "An error occurred while trying to kill the process: $_"
    }
}


#This function kills the process when the most recent file in the specified folder was created past a specified time  ago.
function MonitorFileActivityByCheckingLastModifiedDate{
param(
[string] $FolderPath,
[string]$FilePath,
[int] $MaxDurationInSeconds,
[string] $ProcessName, #Set Name of process
[string]$LogFilePath, #Set Debug Log File Path
[string]$LockFilePath, #Set Lock File Path
[string]$ScreenshotFilePath, #Set Screenshot File Path
[string]$ShouldTakeScreenshot,# set true if you need a screenshot
[string]$ShouldDebug,
[string]$killedProcessFile
)


Write-Host "Caller: Starting Wrapper as a background job"
#Delete residual files i.e screenshot, log and lock file path
DeleteAFile -fileToDelete $ScreenshotFilePath
DeleteAFile -fileToDelete $LogFilePath
DeleteAFile -fileToDelete $LockFilePath
DeleteAFile -fileToDelete $killedProcessFile


WriteToDebugLog -ShouldDebug $ShouldDebug  -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Caller: Starting Wrapper as a background job"

#----------------------check for the process to know if it is still running-------------------------------------
$ProcessCheck = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
#---------------------------------------------------------------------------------------------------------------
$currentDate = Get-Date # set Start time which is used to prevent the while loop from running unlimitedly


#First wait maximum duration for process to start
while (!$ProcessCheck -and ((Get-Date) - $currentDate -le ([TimeSpan]::FromSeconds($MaxDurationInSeconds)))) {
            #----------------------check for the process to know if it is still running-------------------------------------
            $ProcessCheck = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            #---------------------------------------------------------------------------------------------------------------
            # Wait for some time before checking again
            Start-Sleep -Seconds 2
       }


$currentDate = Get-Date # Reset Current

if(($FilePath) -and (Test-Path $FilePath -PathType Leaf)){
#Get the last modified date
$PreviousModifiedDate = (Get-Item $FilePath).LastWriteTime

#Now if the Process is opened and the specified file exist we proceed to last modified date.
while (($ProcessCheck) -and ($FilePath) -and (Test-Path $FilePath -PathType Leaf)){


        #Check the maximum duration of this code is not exceeded
       if ((Get-Date) - $currentDate -ge ([TimeSpan]::FromSeconds($MaxDurationInSeconds))){

        WriteToDebugLog -ShouldDebug $ShouldDebug  -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: maximum time duration to keep waiting for last modified date of file to change was exceeded"
        Write-Host "maximum duration has been exceeded."
        break
        }

        #Get the current modified date 
        $CurrentModifiedDate = (Get-Item $FilePath).LastWriteTime


        if ($CurrentModifiedDate -ne $PreviousModifiedDate) {

            $PreviousModifiedDate = $CurrentModifiedDate # set previousmodified date to current
            $currentDate = Get-Date # Reset Current date
        }


       #we sleep for 1 second
       Start-Sleep -Seconds 1
  }

}
elseif (!$FilePath){
 WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "File path was not specified"
} elseif(!(Test-Path $FilePath -PathType Leaf)){
 WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Specified file path $FilePath does not exist"
}




#check for the process to know if it is still running - this to kill it 
$ProcessCheck = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

if($ProcessCheck){
        #Taking screenshot before killing process
        WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Taking screenshot before killing process"
        TakeAScreenShot -ScreenshotFilePath $ScreenshotFilePath
        WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Screenshot saved in $ScreenshotFilePath"
        # Now killing Process here
        WriteToDebugLog -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: Killing ${ProcessName} process"
        KillAProcessByName -ProcessName $ProcessName
        WriteToDebugLog -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: ${ProcessName} process killed."
        WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: Creating Killed text file at $killedProcessFile"
        New-Item -Path $killedProcessFile -ItemType File -Force > $null
        WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: Killed text file created at $killedProcessFile"
    }
else{
        Write-Host "process closed on its own and was NOT killed by wrapper script."
        WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: ${ProcessName} process closed on its own and was NOT killed by wrapper script."
    }


# wrapper script finished
WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: wrapper script finished"

}


#Calling Main Function here
MonitorFileActivityByCheckingLastModifiedDate -ShouldDebug $ShouldDebug -FolderPath $FolderPath -FilePath $FilePath -MaxDurationInSeconds $MaxDurationInSeconds -MaxAgeOfFileInSeconds 5 -ProcessName $ProcessName -killedProcessFile (Join-Path -Path $FolderPath -ChildPath "Killed_$ProcessName.txt") -ShouldTakeScreenshot $ShouldTakeScreenshot -LogFilePath (Join-Path -Path $FolderPath -ChildPath "PS_Wrapper.log") -LockFilePath (Join-Path -Path $FolderPath -ChildPath "PS_Wrapper.log.lock") -ScreenshotFilePath (Join-Path -Path $FolderPath -ChildPath "shot.png")

}

$job = Start-Job -ScriptBlock $wrapperScriptBlock -ArgumentList @($ProcessName, $MaxDurationInSeconds, $FolderPath, $FilePath, $ShouldTakeScreenshot, $ShouldDebug)


