
//-Blue Prism Begin-----------------------------------------------------

//-Initialization of output variables-----------------------------------
ErrorMessage = "";
Result = "";
string PSCode = PowerShellCode;

//-Open the runspace----------------------------------------------------
Runspace runspace;

try {

  runspace = RunspaceFactory.CreateRunspace();
  
  //Event handler to close runspace when process finished to prevent memory leaks.
  runspace.StateChanged += (sender, eventArgs) =>
	{
		if (eventArgs.RunspaceStateInfo.State == RunspaceState.Closed ||
			eventArgs.RunspaceStateInfo.State == RunspaceState.Broken)
		{
			runspace.Dispose();
		}
	};

  runspace.ApartmentState = System.Threading.ApartmentState.STA;
  runspace.ThreadOptions = PSThreadOptions.ReuseThread;
  runspace.Open();

} catch(System.Exception ex) {
  ErrorMessage = ex.Message;
  return;
}


//-Create PowerShell----------------------------------------------------
System.Management.Automation.PowerShell PS;

try {

  PS = System.Management.Automation.PowerShell.Create();
  PS.Runspace = runspace;
  PS.AddScript(PSCode);

} catch(System.Exception ex) {
  runspace.Close();
  ErrorMessage = ex.Message;
  return;
}

//-Add parameters to PowerShell-----------------------------------------
PS.AddParameter("ProcessName", ProcessName);
PS.AddParameter("MaxDurationInSeconds", MaxDurationInSeconds);
PS.AddParameter("MaxAgeOfFileInSeconds", MaxAgeOfFileInSeconds);
PS.AddParameter("ShouldTakeScreenshot", ShouldTakeScreenshot.ToString());
PS.AddParameter("ShouldDebug", ShouldDebug.ToString());
PS.AddParameter("FolderPath", WorkingDirectory);


//-Invoke PowerShell----------------------------------------------------
try {

  Collection<PSObject> Ret = PS.Invoke();
  

  //-Set Result---------------------------------------------------------
  StringBuilder stringBuilder = new StringBuilder();
  foreach(PSObject oPS in Ret) {
    stringBuilder.AppendLine(oPS.ToString());
  }
  Result = stringBuilder.ToString();

} catch(System.Exception ex) {
  ErrorMessage = ex.Message;
  return;
}

//-Blue Prism End-------------------------------------------------------
