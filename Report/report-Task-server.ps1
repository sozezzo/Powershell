<#

    report-Task-server.ps1
    
    Reads Task Scheduler configuration from all Windows servers in the current domain 
    and generates report listing all Task "Run as user" account.
    
    Version history: 
        08.08.2020 First release

    #Reference : https://docs.microsoft.com/en-us/windows/win32/taskschd/schtasks

#>

Clear

## Dependencies
# Import-Module TaskScheduler
# Get-ScheduledTask -Recurse

## Begin Configuration ##

$FilterServerLike  = "*"   ## Filter server
$FilterTaskLike    = "*"   ## Filter Task Scheduler name

$Ignore_MicrosoftTask            = 1  ## Microsoft
$IgnoreRunAsUser_SYSTEM          = 0  ## SYSTEM / NETWORK SERVICE / NETWORK SERVICE
$IgnoreLogonMode_INTERACTIVE     = 1  ## INTERACTIVE
$ListServer                      = 1  ## Create table -- Server | #Tasks | Access status
$reportFile = "$env:TEMP\report_Task_server.html"
## End Configuration ##

## Global variables ##
$currentDomain = $env:USERDOMAIN.ToUpper()
$TaskList = @{}
$ServerList = @{}
[string[]]$warnings = @() 


function get-server-info()
{
    param( $hostname )
    
    if ( Test-Connection -ComputerName $hostname -Count 3 -Quiet ){
        try {
            # retrieve Task list form a remove machine
            
            $Tasks = schtasks.exe /query /s $hostname /V /FO CSV | ConvertFrom-Csv | Where { $_.TaskName -ne "TaskName" }

            ## Microsoft bug ##
            ## https://social.technet.microsoft.com/Forums/Lync/en-US/6f9a0328-d4a1-4c8f-a85d-910b458c35be/task-lttaskgt-the-task-xml-contains-a-value-which-is-incorrectly-formatted-or-out-of-range?forum=win10itprogeneral
            ## https://docs.microsoft.com/en-ca/archive/blogs/ramazancan/the-task-xml-contains-a-value-which-is-incorrectly-formatted-or-out-of-range
            $TasksNoLoad = $Tasks | Where-Object {$_.HostName  -like "ERROR: Task cannot be loaded*" } 
            $Tasks = $Tasks | Where-Object {$_.HostName  -Notlike "ERROR: Task cannot be loaded*" } 
            
            ##############################
            # reads Task list
            
            if ( $Tasks.GetType() -eq [Object[]] ){
                try
                {
                    $ServerStatus = ""
                    if ( $TasksNoLoad.Count -ige 1)
                    {
                        $ServerStatus = "ERROR: There are tasks cannot be loaded"
                    }

                    if ($Tasks.Count -ge 1)
                    {
                        $arrID = $script:ServerList.Count+1
                        $ItemInfo    = $hostname, $($Tasks.Count), $ServerStatus 
                        $script:ServerList.Add( $arrID, @( $ItemInfo ) ) 
                    } else
                    {
                        $arrID = $script:ServerList.Count+1
                        $ItemInfo    = $hostname, "", $ServerStatus 
                        $script:ServerList.Add( $arrID, @( $ItemInfo ) ) 
                    }

                    #Apply Filter
                    if ($Ignore_MicrosoftTask             -eq 1) { $Tasks = $Tasks | Where-Object {$_.Author        -notlike "Microsoft Corporation" } }
                    if ($Ignore_MicrosoftTask             -eq 1) { $Tasks = $Tasks | Where-Object {$_.Author        -notlike "Microsoft" } }
                    if ($Ignore_MicrosoftTask             -eq 1) { $Tasks = $Tasks | Where-Object {$_.TaskName      -notlike "\Microsoft\*" } }
                    if ($IgnoreRunAsUser_SYSTEM           -eq 1) { $Tasks = $Tasks | Where-Object {$_.”Run As User” -notlike "SYSTEM" } }
                    if ($IgnoreRunAsUser_SYSTEM           -eq 1) { $Tasks = $Tasks | Where-Object {$_.”Run As User” -notlike "NT AUTHORITY*" } }
                    if ($IgnoreRunAsUser_SYSTEM           -eq 1) { $Tasks = $Tasks | Where-Object {$_.”Run As User” -notlike "NETWORK SERVICE" } }
                    if ($IgnoreLogonMode_INTERACTIVE      -eq 1) { $Tasks = $Tasks | Where-Object {$_.”Logon Mode” -notlike "INTERACTIVE" } }
                    if ($IgnoreLogonMode_INTERACTIVE      -eq 1) { $Tasks = $Tasks | Where-Object {$_.”Logon Mode” -notlike "Interactive only" } }
                    
                    if ($FilterTaskLike -ne "*")                 { $TaskList = $TaskList | Where-Object {$_.TaskName -like $FilterTaskLike } }

                    foreach( $Task in $Tasks ){
                        
                        $arrID = $script:TaskList.Count+1
                        $ItemInfo = $Task.HostName, $Task."Logon Mode", $Task.”Run As User”, $Task.Author, $Task.TaskName, $Task.Status, $Task.”Last Run Time”, $Task.”Next Run Time” 
                        $ItemInfo 

                        $script:TaskList.Add( $arrID, @( $ItemInfo ) ) 

                    }
                }
                catch {}
            }
            elseif ( $data.GetType() -eq [String] ) 
            {
                $script:warnings += "Fail to read Task info"
            }

        }
        catch
        {
            $global:warnings += @("$hostname | Failed to retrieve data $($_.toString())")
            $arrID = $script:ServerList.Count+1
            $ItemInfo    = $hostname, "", "Failed" 
            $script:ServerList.Add( $arrID, @( $ItemInfo ) ) 
        }
    }
    else
    {
        $global:warnings += @("$hostname | unreachable")
        $arrID = $script:ServerList.Count+1
        $ItemInfo    = $hostname, "", "Unreachable" 
        $script:ServerList.Add( $arrID, @( $ItemInfo ) ) 
    }    
}


#################    MAIN   #################


## Add-WindowsFeature RSAT-AD-PowerShell
Import-Module ActiveDirectory


# read computer accounts from current domain
Write-Progress -Activity "Retrieving server list from ActiveDirectory" -Status "Processing..." -PercentComplete 0 
$serverTaskList = Get-ADComputer -Filter {OperatingSystem -like "Windows Server*"} -Properties DNSHostName, cn | Where-Object {$_.Name -like $FilterServerLike } | ? { $_.enabled } 

$count_servers = 0
$TotalServer = $($serverTaskList.Count)
foreach( $server in $serverTaskList ){

    $dnshostname = $server.dnshostname
    $dnshostname

    ++$count_servers
    if ($TotalServer -ige 1)
    {
        Write-Progress -Activity "Retrieving data from server $dnshostname ( $count_servers / $TotalServer ) " -Status "Processing..." -PercentComplete ( $count_servers * 100 / $TotalServer )
    }
   
    get-server-info $server.dnshostname

}

# prepare data table for report
Write-Progress -Activity "Generating report" -Status "Please wait..." -PercentComplete 0

$TaskTable = @()
foreach( $value in $TaskList.Values )  
{

        $row = new-object psobject
        Add-Member -InputObject $row -MemberType NoteProperty -Name "HostName"              -Value $(($value)[0])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Logon Mode"            -Value $(($value)[1])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Run As User"           -Value $(($value)[2])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Author"                -Value $(($value)[3])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "TaskName"              -Value $(($value)[4])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Status"                -Value $(($value)[5])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Last Run Time"         -Value $(($value)[6])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Next Run Time"         -Value $(($value)[7])
        $TaskTable  += $row

}


$ServerTable = @()
foreach( $value in $ServerList.Values )  
{

        $row = new-object psobject
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Server"    -Value $(($value)[0])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Tasks"     -Value $(($value)[1])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Status"    -Value $(($value)[2])
        $ServerTable  += $row
}

#################
# create report
$datenow = Get-Date -format "yyyy-MMM-dd HH:mm"
$report = "
<!DOCTYPE html>
<html>
<head>
<style>
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;white-space:nowrap;} 
TH{border-width: 1px;padding: 4px;border-style: solid;border-color: black} 
TD{border-width: 1px;padding: 2px 10px;border-style: solid;border-color: black} 
</style>
</head>
<body> 
<H1>Task & Server report for $currentDomain domain</H1> 
<H3>Server Filter : $FilterServerLike</br>
Task Filter : $FilterTaskLike</br>
Login : $env:UserDomain\$env:UserName</br>
Date : $datenow
</H3>

<H2>Discovered Task accounts</H2>
$( $TaskTable | Sort TaskName | select HostName, "Logon Mode", ”Run As User”, Author, TaskName, Status, ”Last Run Time”, ”Next Run Time” -Unique | ConvertTo-Html HostName, "Logon Mode", ”Run As User”, Author, TaskName, Status, ”Last Run Time”, ”Next Run Time” -Fragment )
Discovered $($TaskTable.count) Tasks.
</br>

<H2>Discovered servers</H2>
$( $ServerTable | Sort Status, Server   | ConvertTo-Html Server, Tasks, Status -Fragment )
$($serverList.count) servers processed. 
</br>

<H2>Warning messages</H2> 
$( $warnings | % { "<p>$_</p>" } )


</body>
</html>"  

Write-Progress -Activity "Generating report" -Status "Please wait..." -Completed
$report  | Set-Content $reportFile -Force 
Invoke-Expression $reportFile 
 