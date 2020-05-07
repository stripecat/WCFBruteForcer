# WCFBruteForcer
A Powershell-script that uses WcfScan to brute force WCF (Windows Communication Foundation) Endpoints.
Created by Erik Zalitis 2020 (StripeCAT) for all you crazy pentesters out there!

Introduction
If you're a pentester trying to enumerate WCF endpoints, this is the tool for you. It requires WCFScan (https://github.com/malcomvetter/WcfScan) to work and adds the capability to brute force multiple URLs at the same time and write the results in a logfile.

Disclaimer
This tool is provided "as is". I take no responsibility for any consequences of using this tool. Please read the this text before using it.

Installation
Clone WCFBruteForcer to a local directory on youyr system.
Get WCFScan (https://github.com/malcomvetter/WcfScan) and copy WcfScan\WcfScan\bin\Debug\WcfScan.exe to WCFBruteForcers directory.

The directory should now look like this:

Contracts.txt
Hosts.txt
README.md
WCFBruteForcer.ps1
WcfScan.exe

Now edit WCFBruteForcer.ps1 and change the following values if you want to (This is optional):
$debug=1 # Will print even WCF endpoints that does not allow you to connect in the log if set to 1.
$maxdop=10 # How many jobs can spawn at the same time. One job can consume as much as 100 MB, so caution is adviced when considering to increase this number.

A little bit down the file, you'll find
$maxruntime=480 # Maximum time of execution for each spawned job.

Open Hosts.txt and add all URLs you want to scan. One line per url. Don't forget the portnumber!

Open a PS terminal and navigate to the folder containing the file.
run:
.\WCFBruteForcer.ps1

When the script has completed, a file named something like ScanResult_2020-05-07-19-19.txt will appear in the same folder as the rest of the files.

Open this file and search for the word "[Attention]". Any entries tagged with this is active endpoints found by the script.

It's highly recommended that you change the Contracts.txt file to add useful Contracts to search for. In it's default state it's taken for the dirbuster-project and contains about 2000 words to test.


