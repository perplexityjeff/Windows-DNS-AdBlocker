Write-Host "===================================================="
Write-Host "Windows-DNS-AdBlocker"
Write-Host "===================================================="

function Insert-Content ($file) {
BEGIN {
$content = Get-Content $file
}
PROCESS {
$_ | Set-Content $file
}
END {
$content | Add-Content $file
}
}	
	
#Declares
$url = "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=win32reg-sp4&showintro=0&mimetype=plaintext" 

$adserversurl = "https://raw.githubusercontent.com/perplexityjeff/Windows-DNS-AdBlocker/master/adservers.dns"
$adserverstemp = "C:\DNS Blacklist\adservers.dns"
$adserverslocation = "C:\Windows\System32\dns\adservers.dns"

$date = Get-Date -format "yyyyMMdd"
$blacklist = "C:\DNS Blacklist\Blacklist_" + $date +".reg"  
$path = "C:\DNS Blacklist\"
$limit = (Get-Date).AddDays(-15)

#Testing if DNS Blacklist folder exists
Write-Host "Detecting if download location exists..."
If (Test-Path $path)
{  
	Write-Host "Download location exists"   
}
Else
{
	New-Item $path -ItemType directory
	Write-Host "Download location has been created"
}   

#Testing if adservers.dns file exists
Write-Host "Detecting if adservers.dns file exists..."
If (-Not(Test-Path $adserverslocation))
{
	Write-Host "Downloading default adservers.dns file..."
	$client = new-object System.Net.WebClient 
	$client.DownloadFile($adserversurl, $adserverstemp) 
	Write-Host "Downloaded default adservers.dns file"
	
	Write-Host "Placing downloaded adservers.dns file in the systemroot..."
	Move-Item $adserverstemp $adserverslocation
	Write-Host "Placed downloaded adservers.dns file in the systemroot"
}
Else
{
	Write-Host "Detected adservers.dns file"
}

#Testing if DNS Blacklist exists
Write-Host "Detecting if older DNS Blacklist exists..."
If (Test-Path $blacklist)
{  
	Write-Host "Deleting old DNS Blacklist..."
	Remove-Item ($blacklist)   
	Write-Host "Deleted old DNS Blacklist"
}
Else
{
	Write-Host "No existing DNS Blacklist found"
}  

#Downloading of the Adblock reg file
Write-Host "Downloading newest AdBlock file..."       
if(!(Split-Path -parent $path) -or !(Test-Path -pathType Container (Split-Path -parent $path))) 
{ 
	$path = Join-Path $pwd (Split-Path -leaf $path) 
}
try 
{
	$client = new-object System.Net.WebClient 
	$client.DownloadFile($url, $blacklist) 
	"REGEDIT4`n" | Insert-Content $blacklist
	Write-Host "Downloaded newest AdBlock file"
}
catch
{
	Write-Error "Download of the DNS Blacklist failed"
	Exit
}

Write-Host "Detecting if new DNS Blacklist exists..."
If (-Not(Test-Path $blacklist))
{  
	Write-Error "Download of the DNS Blacklist failed"
	Exit
}

#Stopping the DNS Server
Write-Host "Stopping DNS Server..."
Get-Service | Where {$_.Name -Eq "DNS"} | Stop-Service
Write-Host "Stopped DNS Server"

#Remove All Old Entries (CAUTION: Be sure to tweak this to your environment and not delete valid DNS entries)
Write-Host "Deleting old Blacklist entries from Registry"
Get-ChildItem "HKLM:\software\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones\" | 
   ForEach-Object {
       $CurrentKey = (Get-ItemProperty -Path $_.PsPath)
       If ($CurrentKey -match "adservers.dns"){
         $CurrentKey|Remove-Item -Force #-Whatif
       }
    }
Write-Host "Deleted old Blacklist entries from Registry"

#Importing the file into regedit
Write-Host "Importing AdBlock file..." 
regedit.exe /s $blacklist
Write-Host "Imported AdBlock file"

#Starting the DNS Server
Write-Host "Starting DNS Server..."
Get-Service | Where {$_.Name -Eq "DNS"} | Start-Service
Write-Host "Started DNS Server"
	
#Removing Blacklist files older then 15 days
Write-Host "Removing old AdBlock files..."
Get-ChildItem -Path $path -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
Write-Host "Removed old AdBlock files"

#Script has been completed
Write-Host "Script has been completed"
