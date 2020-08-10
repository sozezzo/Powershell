<#

    report-service-server.ps1
    
    Reads service configuration from all Windows servers in the current domain 
    and generates report listing all service logon account.
    
    Version history: 
        08.08.2020 First release

    #Reference : https://gallery.technet.microsoft.com/scriptcenter/PowerShell-script-to-find-6fc15ecb
                 * Use Job and missing nice features

#>

Clear

## Begin Configuration ##

$FilterServerLike  = "*"   ## Filter server
$FilterServiceLike = "*"   ## Filter service

## Search for all server and all services ##
#$FilterServerLike = "*sql*"      ## Search all server : "*"
#$FilterServiceLike = "*SQL*"     ## Search service

## Search for all server *sql* and all services *sql* ##
#$FilterServerLike = "*sql*"   ## Search all server : "*"
#$FilterServiceLike = "MSSQL*"     ## Search service


$IgnoreAccount_NT_Service   = 1  ## NT Service
$IgnoreAccount_NT_AUTHORITY = 1  ## NT AUTHORITY
$IgnoreAccount_LocalSystem  = 1  ## LocalSystem
$ListServer                 = 1  ## Create table -- Server | #Services | Access status
$reportFile = "$env:TEMP\report_service_server.html"
## End Configuration ##

## Global variables ##
$ErrorActionPreference = "Stop"
$currentDomain = $env:USERDOMAIN.ToUpper()
$ServiceList = @{}
$ServerList = @{}
[string[]]$warnings = @() 


function get-server-info()
{
    param( $hostname )
    
    if ( Test-Connection -ComputerName $hostname -Count 3 -Quiet ){
        try {
            # retrieve service list form a remove machine
            $serviceList = @( gwmi -Class Win32_Service -ComputerName $hostname -Property Name,StartName,SystemName -ErrorAction Stop )
            ##$serviceList

            ##############################
            # reads service list
            
            if ( $serviceList.GetType() -eq [Object[]] ){
                try
                {
                    $serviceList = $serviceList | ? { $_.StartName.toUpper() }

                    if ($serviceList.Count -ge 1)
                    {
                        $arrID = $script:ServerList.Count+1
                        $ItemInfo    = $hostname, $($serviceList.Count), "" 
                        $script:ServerList.Add( $arrID, @( $ItemInfo ) ) 
                    } else
                    {
                        $arrID = $script:ServerList.Count+1
                        $ItemInfo    = $hostname, "", "no services" 
                        $script:ServerList.Add( $arrID, @( $ItemInfo ) ) 
                    }

                    #Apply Filter
                    if ($IgnoreAccount_NT_Service   -eq 1) { $serviceList = $serviceList | Where-Object {$_.StartName -notlike "NT Service\*" }   | ? { $_.StartName } }
                    if ($IgnoreAccount_NT_AUTHORITY -eq 1) { $serviceList = $serviceList | Where-Object {$_.StartName -notlike "NT AUTHORITY\*" } | ? { $_.StartName } }
                    if ($IgnoreAccount_LocalSystem  -eq 1) { $serviceList = $serviceList | Where-Object {$_.StartName -notlike "LocalSystem" }    | ? { $_.StartName } }

                    if ($FilterServiceLike -ne "*") { $serviceList = $serviceList | Where-Object {$_.Name -like $FilterServiceLike } }

                    foreach( $service in $serviceList ){

                        $arrID = $script:ServiceList.Count+1
                        $ItemInfo    = $service.StartName, $($service.Name), $($service.SystemName)
                    
                        $script:ServiceList.Add( $arrID, @( $ItemInfo ) ) 

                    }
                }
                catch {}
            }
            elseif ( $data.GetType() -eq [String] ) 
            {
                $script:warnings += "Fail to read service info"
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
$serverServiceList = Get-ADComputer -Filter {OperatingSystem -like "Windows Server*"} -Properties DNSHostName, cn | Where-Object {$_.Name -like $FilterServerLike } | ? { $_.enabled } 

$count_servers = 0
foreach( $server in $serverServiceList ){

    $dnshostname = $server.dnshostname
    $dnshostname

    ++$count_servers
    Write-Progress -Activity "Retrieving data from server $dnshostname ( $count_servers / $($serverServiceList.Count) ) " -Status "Processing..." -PercentComplete ( $count_servers * 100 / $serverServiceList.Count )
   
    get-server-info $server.dnshostname

}

# prepare data table for report
Write-Progress -Activity "Generating report" -Status "Please wait..." -PercentComplete 0

$ServiceTable = @()
foreach( $value in $serviceList.Values )  
{

        $row = new-object psobject
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Account" -Value $(($value)[0])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Service" -Value $(($value)[1])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Server"  -Value $(($value)[2])
        $ServiceTable  += $row
}

$ServerTable = @()
foreach( $value in $ServerList.Values )  
{

        $row = new-object psobject
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Server"    -Value $(($value)[0])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Services"  -Value $(($value)[1])
        Add-Member -InputObject $row -MemberType NoteProperty -Name "Status"    -Value $(($value)[2])
        $ServerTable  += $row
}

#################
# create report
$datenow = Get-Date -format "yyyy-MMM-dd HH:mm"
$report = "<!DOCTYPE html>
<html>
<head>
<style>
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;white-space:nowrap;} 
TH{border-width: 1px;padding: 4px;border-style: solid;border-color: black} 
TD{border-width: 1px;padding: 2px 10px;border-style: solid;border-color: black} 
</style>
</head>
<body> 
<H1>Service & Server report for $currentDomain domain</H1> 
<H3>Server Filter : $FilterServerLike</br>
Service Filter : $FilterServiceLike</br>
Login : $env:UserDomain\$env:UserName</br>
Date : $datenow
</H3>

<H2>Discovered service accounts</H2>
$( $ServiceTable | Sort Account | ConvertTo-Html Account, Service, Server -Fragment )
Discovered $($ServiceTable.count) services.
</br>

<H2>Discovered servers</H2>
$( $ServerTable | Sort Status, Server   | ConvertTo-Html Server, Services, Status -Fragment )
$($serverList.count) servers processed. 
</br>

<H2>Warning messages</H2> 
$( $warnings | % { "<p>$_</p>" } )


</body>
</html>"  

Write-Progress -Activity "Generating report" -Status "Please wait..." -Completed
$report  | Set-Content $reportFile -Force 
Invoke-Expression $reportFile 
 