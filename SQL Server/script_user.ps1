<#
    .SYNOPSIS 
     Scritps a given user, from a given server and database.
    .EXAMPLE
     script-user.ps1 -serverName "mycomputer\myinstance" -databaseName MyDatabase -login TestUser -logtofile
#>
param (
      [string]$serverName = $(throw "-serverName is required.")
#    , [string]$databaseName = $(throw "-databaseName is required.")
    , [string]$login = $(throw "-login is required.")
    , [switch]$logtofile
    )
# CONFIGURATION
$ScriptSavePath = 'C:\Downloads\SQL_Scripts\'

#Reset parameters, to avoid variable pollution
$psid, $phash, $ppwd, $file_content, $log = ''

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null 
Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Connecting to $serverName"
$log += Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Connecting to $serverName`r`n"
$connection = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName 

if ($connection.State -ne 'Existing') {
    Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Connection failed! Unable to connect to server or database."
    $log += "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Connection failed! Unable to connect to server or database.`r`n"
    Break :end
}
    
if ($connection.Logins[$login]) {
    Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Scripting user $login"
    $log += "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Scripting user $login`r`n"
}
else {
    Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Sorry, but the user given was not found!"
    $log += "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Sorry, but the user given was not found!`r`n"
    Break
}



foreach ($specified_user in $connection.Logins[$login]) 
{
    if ("WindowsGroup", "WindowsUser" -notcontains $specified_user.LoginType) 
    { 
        #Write-Output "SID: " + $connection.Logins.Sid
        $specified_user.Sid| % {$psid += ("{0:X}" -f $_).PadLeft(2, "0")} 
        [byte[]] $phash = $connection.Databases["master"].ExecuteWithResults("select hash=cast(loginproperty('$($specified_user.Name)', 'PasswordHash') as varbinary(256))").Tables[0].Rows[0].Hash
        $ppwd = "" 
        $phash | % {$ppwd += ("{0:X}" -f $_).PadLeft(2, "0")} 
    } 

    if ("WindowsGroup", "WindowsUser" -contains $specified_user.LoginType) 
    { 
        $file_content += "CREATE LOGIN [$($specified_user.Name)] FROM WINDOWS WITH default_database = [$defaultDatabase];" 
    } 
    else 
    { 
        if ($specified_user.PasswordExpirationEnabled) 
        { 
            $checkExpiration = "on" 
        } 
        else 
        { 
            $checkExpiration = "off" 
        } 
        if ($specified_user.PasswordPolicyEnforced) 
        { 
            $checkPolicy = "on" 
        } 
        else 
        { 
            $checkPolicy = "off" 
        } 
        $file_content += "CREATE LOGIN [$($specified_user.Name)] WITH PASSWORD = 0x$ppwd HASHED, SID = 0x"+$psid+", DEFAULT_DATABASE = [$defaultDatabase], CHECK_POLICY = $checkPolicy, CHECK_EXPIRATION = $checkExpiration;"
        if ($login.DenyWindowsLogin) 
        { 
            $file_content += "DENY CONNET SQL TO [$($specified_user.Name)];" 
        } 
        if (-not $specified_user.HasAccess) 
        { 
            $file_content += "REVOKE CONNET SQL TO [$($specified_user.Name)];" 
        } 
        if ($specified_user.IsDisabled) 
        { 
            $file_content += "ALTER LOGIN [$($specified_user.Name)] DISABLE;" 
        } 
        Break
    } 
}
$filename = $login -replace '\\','_'
Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Exporting $login from $serverName"
$log += "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Exporting $login from $serverName`r`n"
Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Writing Output file $filename.sql"
$log += "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Writing Output file $filename.sql`r`n"
$outpath = $ScriptSavePath + '\' + $connection.Information.FullyQualifiedNetName+'\'+$connection.InstanceName+'\logins\'
New-Item -ItemType Directory -Force -Path $outpath | Out-Null
Out-File -FilePath $outpath$filename'.sql' -InputObject $file_content | Out-Null
Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Script ended..."
$log += "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") Script ended...`r`n"
if ($logtofile -eq $true) {
  $outfile = $ScriptSavePath+'\'+$connection.Information.FullyQualifiedNetName+'\'+$connection.InstanceName+'\output.log'
  Out-File -FilePath $outfile -Append -InputObject $log | Out-Null
}
