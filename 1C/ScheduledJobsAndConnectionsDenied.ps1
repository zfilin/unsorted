if ($args.Length -lt 5) {
    Write-Output @"

The script enables and disables the blocking of scheduled tasks and connections to the infobase

Usage: 
    ScheduledJobsAndConnectionsDenied <on|off> <WorkProcessName> <DatabaseName> <UserName> <Password> [<PermissionCode>] [<DeniedTimeMinutes>] [<DeniedMessage>]

Example:
    ScheduledJobsAndConnectionsDenied on "server:1562" "base1c" "robot_user" "12345678" "123" 60 "Please wait, the database is being updated..."
        - enable blocking

    ScheduledJobsAndConnectionsDenied off "server:1562" "base1c" "robot_user" "12345678"
        - disable blocking

"@
exit 1
}

if ($args[0] -eq "on") {
    $on = $true;
} else {
    $on = $false;
}
$WorkProcessName = $args[1]
$BaseName = $args[2]
$UserName = $args[3]
$Password = $args[4]
if ($args.Length -gt 5) {
    $PasswordUC = $args[5]
} else {
    $PasswordUC = ""
}
if ($args.Length -gt 6) {
    $DeniedTimeMinutes = $args[6]
} else {
    $DeniedTimeMinutes = $null
}
if ($args.Length -gt 7) {
    $DeniedMessage = $args[7]
} else {
    $DeniedMessage = ""
}

try { 

    $Connector = New-Object -com V83.COMConnector

    $WorkProcessConnector = $Connector.ConnectWorkingProcess($WorkProcessName)
    $WorkProcessConnector.AddAuthentication($UserName, $Password)

}
catch {
    Write-Error $_
    exit 1
}
    
$DatabaseArray = $WorkProcessConnector.GetInfoBases()

$FoundBase = $null
foreach ($Database in $DatabaseArray)
{
    if($Database.Name -eq $BaseName) {
        $FoundBase = $Database
        break
    }
}

if ($FoundBase -eq $null) {
    Write-Error "Database $BaseName not found"
    exit 1
}

$FoundBase.ScheduledJobsDenied = $on

$FoundBase.ConnectDenied = $on
$FoundBase.PermissionCode = $PasswordUC
if ($DeniedTimeMinutes -ne $null) {
    $FoundBase.DeniedFrom = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FoundBase.DeniedTo = (Get-Date).AddSeconds(($DeniedTimeMinutes -as [int]) * 60).ToString("yyyy-MM-dd HH:mm:ss")
}
$FoundBase.DeniedMessage = $DeniedMessage

try { 
    $WorkProcessConnector.UpdateInfoBase($FoundBase)
}
catch {
    Write-Error $_
    exit 1
}

Write-Output "Complete"
