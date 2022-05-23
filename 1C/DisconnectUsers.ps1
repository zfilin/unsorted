if ($args.Length -lt 6) {
    Write-Output @"

The script disconnect active users connections

Usage: 
    DisconnectUsers <WorkProcessName> <DatabaseName> <UserName> <Password> <ClusterAdminUserName> <ClusterAdminPassword>

Example:
    DisconnectUsers "server" "base1c" "robot_user" "12345678" "admin" "12345"

"@
exit 1
}

$WorkProcessName = $args[0]
$BaseName = $args[1]
$UserName = $args[2]
$Password = $args[3]
$AdminUserName = $args[4]
$AdminPassword = $args[5]

try { 

    $Connector = New-Object -com V83.COMConnector
    $AgentConnector = $Connector.ConnectAgent($WorkProcessName)

}
catch {
    Write-Error $_
    exit 1
}

$Clusters = $AgentConnector.GetClusters()
foreach ($Cluster in $Clusters) {
    
    try { 
        $AgentConnector.Authenticate($Cluster, $AdminUserName, $AdminPassword)

        $Sessions = $AgentConnector.GetSessions($Cluster)
        foreach ($Session in $Sessions) {
            if($Session.infoBase.Name -eq $BaseName) {
                $AgentConnector.TerminateSession($Cluster, $Session)
            }
        }
    }
    catch {
        Write-Error $_
        exit 1
    }

    $processCount = 0
    $baseNotFoundCount = 0

    $Processes = $AgentConnector.GetWorkingProcesses($Cluster)
    foreach ($Process in $Processes) {
        
        try { 
            $WorkProcessConnector = $Connector.ConnectWorkingProcess($Process.HostName + ":" + $Process.MainPort)
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

        $processCount++
        if ($FoundBase -eq $null) {
            $baseNotFoundCount++
            continue
        }

        try { 
            $Connections = $WorkProcessConnector.GetInfoBaseConnections($FoundBase)
            foreach ($Connection in $Connections) {
                if($Connection.userName -ne $UserName) {
                    $WorkProcessConnector.Disconnect($Connection)
                }
            }
        }
        catch {
            Write-Error $_
            exit 1
        }

    }

    if ($processCount -eq $baseNotFoundCount) {
        Write-Error "Database $BaseName not found"
        exit 1
    }

}

Write-Output "Complete"