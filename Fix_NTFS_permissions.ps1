if($Credential) 
{     
    $SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting ` 
    -Filter "Path='$SharedFolderPath'" -ComputerName $ComputerName  -Credential $Credential 
} 
else 
{ 
    $SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting ` 
    -Filter "Path='$SharedFolderPath'" -ComputerName $ComputerName 
}
