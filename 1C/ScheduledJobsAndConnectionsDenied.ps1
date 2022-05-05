$WorkProcessName = "server:1562"
$BaseName = "base"
$UserName = "userrobot"
$Password = "********"
$PasswordUC = "***"
$DeniedMessage = "Please wait, the database is being updated..."

try { 

    $Connector = New-Object -com V83.COMConnector

    $WorkProcessConnector = $Connector.ConnectWorkingProcess($WorkProcessName)
    $WorkProcessConnector.AddAuthentication($UserName, $Password)

}
catch {
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
    exit 1
}

if (($args.Length -gt 0) -and ($args[0] -eq "true")) {

    $FoundBase.ScheduledJobsDenied = $true

    $FoundBase.ConnectDenied = $true
    $FoundBase.PermissionCode = $PasswordUC
    $FoundBase.DeniedMessage = $DeniedMessage
    $FoundBase.DeniedFrom = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FoundBase.DeniedTo = (Get-Date).AddHours(3).ToString("yyyy-MM-dd HH:mm:ss")

} else {

    $FoundBase.ScheduledJobsDenied = $false

    $FoundBase.ConnectDenied = $false
    $FoundBase.PermissionCode = ""
    $FoundBase.DeniedMessage = ""

}

$WorkProcessConnector.UpdateInfoBase($FoundBase)
