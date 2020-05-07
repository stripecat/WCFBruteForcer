#requires -version 3
<#
.SYNOPSIS
  WCFBruteForcer scans for WCF endpoints using a wordlist.
.DESCRIPTION
  This tool will let you scan and enumerate WCF endpoints to find them if not possible through other means.
.PARAMETER none
  No paramters are used at this time.
.INPUTS
  None
.OUTPUTS
  Stdout
.NOTES
  Version:        1.0
  Author:         Erik Zalitis
  Creation Date:  2020-05-07
  Purpose/Change: Initial release
  
.EXAMPLE
  WCFBruteForcer.ps1 - runs this program.
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$basepath=$pwd.Path.tostring()

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$wcfscan=$basepath + "\WcfScan.exe"
$hosts=$basepath + "\Hosts.txt"
$contractlists=$basepath + "\Contracts.txt"
$ScannerReport=$basepath + "\ScanResult_" + (get-date -Format yyyy-MM-dd-HH-mm) + ".txt"
$debug=1 # Will print even WCF endpoints that does not allow you to connect in the log if set to 1.
$maxdop=10 # How many jobs can spawn at the same time. One job can consume as much as 100 MB, so caution is adviced when considering to increase this number.

$ErrorActionPreference="Stop"

try
{
    $wcfhosts=get-content $hosts
}
catch
{
    "Could not load host-list. Please check path"
    exit
}


#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Check_Timeout ($jobtrack)
{
# Check if any of the jobs has timed out

$maxruntime=480

$jobtrack.GetEnumerator()|foreach { if ($_.value -ne "Yes") {

    $elapsed=0;
    $elapsed=(New-TimeSpan $($_.value) $(Get-Date));
    
    if ($elapsed.totalminutes -ge $maxruntime) { 
    
    $jobstat=""
    $jobstate=Get-job -name $_.key|select-object state
    if ($jobstate.state -eq "Running") {
        # If a job has overrun its timelimit we must take action.
        $jobtrack.remove($_.key)
        ("Server" + $_.key + " has run for longer than $maxruntime minutes (" + $elapsed.totalminutes + "). Shutting it down.")
        Stop-Job -name $_.key
        Remove-Job -name $_.key -force
    }
  
     } 
}

}

}

function Spawn-Tasks($task,$parallelljobs,$jobname,$worklist,$init="",$contractlists,$wcfscan)
{

# Consideration for sizing parallellism: each spawned job typically requires 100 MB of RAM to run.

$i=0

$usedpara=0

$listserver=0

$done=0

$recjob=New-Object System.Collections.ArrayList

$remaining=$worklist.count

# Remove old jobs if present
$rc=Remove-Job -name ("*"+$jobname+"*") -force

# This array keeps track of all jobs running on the system
$jobtrack = @{"Test"="Yes"}

# The main loop that dispatches the jobs
do {

# Check if any of the jobs has timed out

 $ErrorActionPreference="stop" # Force the script to fail on all "non success". Otherwise we cannot trap lesser faults.
try { Check_Timeout $jobtrack }
catch {
#("Timeout check for servers failed.") 
}

$inuse=get-job -name ("*"+$jobname+"*") 

$usedpara=0

$ErrorActionPreference="stop"
$inuse|ForEach { 
    if($_.state -eq "Running") { $usedpara=$usedpara+1 }  
    if($_.state -ne "Running" -and $_.name ) { 
    $goahead=1
    try { $jobres="";$jobres=Receive-Job $_.name } catch { $goahead=0 }
    ($jobres)
    if ($goahead -eq 1) { if ($jobres -ne $null) { $rc=$recjob.add($jobres) } }
        $jobtrack.remove($_.name);Remove-Job -name $_.name -force }
    }

# Do we have any parallellism slots available?

if ($usedpara -lt $parallelljobs) {

# Got slots! Good let's send one out!

$server=$worklist[$listserver]

 $ErrorActionPreference="stop" # Force the script to fail on all "non success". Otherwise we cannot trap lesser faults.
        
        # Create new job to dispatch
        $rescode=0

$ErrorActionPreference="stop"
        
     try { 
        $fname=""+ $jobname +":" + $server
       
      # Create a an entry for the server and set a timestamp
      $spawntime=get-date
      $jobtrack.add($fname,$spawntime)
      
      # Spawn the jobs
      [ScriptBlock]$sb = [ScriptBlock]::Create($task + " " + $server + " " + "`"" + $contractlists + "`"" + " `"" + $wcfscan + "`"" + " -WarningAction SilentlyContinue")
      [ScriptBlock]$sa = [ScriptBlock]::Create($init)

      $rc=start-job -Name $fname -InitializationScript $sa -scriptblock $sb
            }
       catch { 
       #("Could not spawn job for $server.")
        $rescode=1 }
        
        $listserver = $listserver + 1
        $remaining=$remaining-1



}

Start-Sleep -m 100
}
while ($remaining -gt 0)


# We exited the above loop after servers were assigned jobs. This means that we have up to $parallelism running jobs that we must still wait for!

do
{

# Check if any of the jobs has timed out

 $ErrorActionPreference="stop" # Force the script to fail on all "non success". Otherwise we cannot trap lesser faults.
try { Check_Timeout $jobtrack }
catch { ("Timeout check for servers failed.") }

$running=0
$inuse=get-job -name ($jobname+"*")
$ErrorActionPreference="stop"
$inuse|ForEach { 
    if($_.state -eq "Running") { $usedpara=$usedpara+1;$running=1 }  
    if($_.state -ne "Running" -and $_.name ) { 
    $goahead=1
    try { $jobres="";$jobres=Receive-Job $_.name } catch { $goahead=0 }
    $jobres
    if ($goahead -eq 1) { if ($jobres -ne $null) { $rc=$recjob.add($jobres) } }
        $jobtrack.remove($_.name);Remove-Job -name $_.name -force }
    }
Start-Sleep -m 2000
}
while ($running -eq 1)

}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$init='Function Sweep_WCF ($server,$contractlists,$wcfscan)
{

$resp=""

if ($contractlists -eq $null) { $resp = "No contracts to load." }

$contracts=get-content $contractlists
$i=1
    ForEach ($contract in $contracts)
    {
        $parm="net.tcp://" + $server + "/" + $contract
        $cmd="& " + "`"" + $wcfscan + "`" " + $parm
        $data=Invoke-Expression $cmd
        $count=0
        $count=([regex]::Matches($data, "forcibly dropped" )).count
        if ($count -eq 4)
        {
            if ($debug -ne 333) 
            { 
                $resp=$resp+("No match for " + $contract + " on " + $parm)
                if ($i -lt ($contracts.count)) { $resp=$resp+"`n" }
            }
        }
        else
        {
            $resp=$resp+("[ATTENTION] Please check " + $contract + " on " + $parm + ":" + $data)
            if ($i -lt ($contracts.count)) { $resp=$resp+"`n" }
        }
        $i++
    }

return $resp
}'

"Starting scan of selected hosts."

$adresults=Spawn-Tasks Sweep_WCF $maxdop "wcfs" $wcfhosts $init $contractlists $wcfscan
$adresults|out-file $scannerreport

"Scanning done."
