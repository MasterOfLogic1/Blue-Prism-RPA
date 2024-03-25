param (
    [string]$ProcessName,
    [int]$MaxDurationSeconds = 10,
    [string]$FolderPath = $null,
    [string]$ShouldTakeScreenshot = "False",
    [string]$ShouldDebug = "False"
)




$wrapperScriptBlock = {

param (
    [string]$ProcessName,
    [int]$MaxDurationSeconds,
    [string]$FolderPath = $null,
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



#Main Function : This function kills the process when the count of files in the specified folder doesnt change within a  specified time  ago.
function MonitorFolderActivityByCheckingFileCount {
    param(
        [string]$FolderPath,
        [int]$maxDurationSeconds, #set the maximum time a file count change should be given a chance to occur before terminating wait loop
        [string]$processName,
        [string]$LogFilePath, #Set Debug Log File Path
        [string]$LockFilePath, #Set Lock File Path
        [string]$ScreenshotFilePath, #Set Screenshot File Path
        [string]$ShouldTakeScreenshot,# set true if you need a screenshot
        [string]$ShouldDebug,
        [string]$killedProcessFile
    )
    Write-Host "Started"
    

    #Delete residual files i.e screenshot, log and lock file path
    DeleteAFile -fileToDelete $ScreenshotFilePath
    DeleteAFile -fileToDelete $LogFilePath
    DeleteAFile -fileToDelete $LockFilePath
    DeleteAFile -fileToDelete $killedProcessFile

    WriteToDebugLog -ShouldDebug $ShouldDebug  -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Caller: Starting Wrapper as a background job"

    # Get the initial count of files in the directory
    $initialFileCount = (Get-ChildItem -Path $FolderPath -File).Count
    #----------------------check for the process to know if it is still running-------------------------------------
    $ProcessCheck = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    #---------------------------------------------------------------------------------------------------------------
    $startTime = Get-Date # set Start time which is used to prevent the while loop from running unlimitedly

    #First wait maximum duration for process to start
    while (!$ProcessCheck -and ((Get-Date) - $startTime -le ([TimeSpan]::FromSeconds($maxDurationSeconds)))) {
            #----------------------check for the process to know if it is still running-------------------------------------
            $ProcessCheck = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            #---------------------------------------------------------------------------------------------------------------
            # Wait for some time before checking again
            Start-Sleep -Seconds 2
       }

    $startTime = Get-Date # Reset start time

    # Now if the process has started start checking for changes in file count here
    while ($ProcessCheck) {
        
        #Check the maximum duration of this code is not exceeded
        if ((Get-Date) - $startTime -ge ([TimeSpan]::FromSeconds($maxDurationSeconds))){

        WriteToDebugLog -ShouldDebug $ShouldDebug  -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: maximum time duration to keep checking for changes in count exceeded"
        Write-Host "maximum duration has been exceeded."
        break
        }

        # Get the current count of files in the directory
        $currentFileCount = (Get-ChildItem -Path $FolderPath -File).Count
        # Check if the current file count has increased in the past specified seconds
        if ($currentFileCount -gt $initialFileCount) {
            # If count of file has changed reset timer and continue loop
            $initialFileCount = $currentFileCount
            $startTime = Get-Date # Reset start time
            Write-Host "File count changed within the last the specfied seconds."
        }

        # Wait for some time before checking again
        Start-Sleep -Seconds 2
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
    Write-Host "got here"
        
        WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: ${ProcessName} process closed on its own and was NOT killed by wrapper script."
    }


     # wrapper script finished
     WriteToDebugLog -ShouldDebug $ShouldDebug -LockFilePath $LockFilePath -LogFilePath $LogFilePath -Message "Wrapper: wrapper script finished"
}


#Calling Main Function here
MonitorFolderActivityByCheckingFileCount -ShouldDebug $ShouldDebug -FolderPath $FolderPath -maxDurationSeconds $MaxDurationSeconds -processName $ProcessName -killedProcessFile (Join-Path -Path $FolderPath -ChildPath "Killed_$ProcessName.txt") -ShouldTakeScreenshot $ShouldTakeScreenshot -LogFilePath (Join-Path -Path $FolderPath -ChildPath "PS_Wrapper.log") -LockFilePath (Join-Path -Path $FolderPath -ChildPath "PS_Wrapper.log.lock") -ScreenshotFilePath (Join-Path -Path $FolderPath -ChildPath "shot.png")
  
}




$job = Start-Job -ScriptBlock $wrapperScriptBlock -ArgumentList @($ProcessName, $MaxDurationSeconds, $FolderPath, $ShouldTakeScreenshot, $ShouldDebug)
