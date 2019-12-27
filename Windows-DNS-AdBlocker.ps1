Write-Host "===================================================="
Write-Host "Windows-DNS-AdBlocker"
Write-Host "===================================================="

function Insert-Content ($file)
{
	BEGIN
 {
		$content = Get-Content $file
	}
	PROCESS
 {
		$_ | Set-Content $file
	}
	END
 {
		$content | Add-Content $file
	}
}

#Declares
$url = "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=win32reg-sp4&showintro=0&mimetype=plaintext"
$adServerZoneFile = "adservers.dns"
$adserversurl = "https://raw.githubusercontent.com/perplexityjeff/Windows-DNS-AdBlocker/master/$adServerZoneFile"
$adserverstemp = "C:\DNS Blacklist\$adServerZoneFile"
$adserverslocation = "C:\Windows\System32\dns\$adServerZoneFile"

$date = Get-Date -format "yyyyMMdd"
$blacklist = "C:\DNS Blacklist\Blacklist_" + $date + ".reg"
$path = "C:\DNS Blacklist\"
$limit = (Get-Date).AddDays(-15)

try
{
	# Test if DNS server exists on this host
	if (-not (Get-Service -Name DNS -ErrorAction SilentlyContinue))
 	{
		throw "Local DNS server not found"
	}

	#Testing if DNS Blacklist folder exists
	Write-Host "Detecting if download location exists..."
	if (Test-Path $path)
 	{
		Write-Host "Download location exists"
	}
	else
 	{
		New-Item $path -ItemType directory
		Write-Host "Download location has been created"
	}

	#Testing if $adServerZoneFile file exists
	Write-Host "Detecting if $adServerZoneFile file exists..."
	if (-Not(Test-Path $adserverslocation))
 	{
		Write-Host "Downloading default $adServerZoneFile file..."
		$client = new-object System.Net.WebClient
		$client.DownloadFile($adserversurl, $adserverstemp)
		Write-Host "Downloaded default $adServerZoneFile file"

		Write-Host "Placing downloaded $adServerZoneFile file in the systemroot..."
		Move-Item $adserverstemp $adserverslocation
		Write-Host "Placed downloaded $adServerZoneFile file in the systemroot"
	}
	else
 	{
		Write-Host "Detected $adServerZoneFile file"
	}

	#Testing if DNS Blacklist exists
	Write-Host "Detecting if older DNS Blacklist exists..."
	if (Test-Path $blacklist)
 	{
		Write-Host "Deleting old DNS Blacklist..."
		Remove-Item ($blacklist)
		Write-Host "Deleted old DNS Blacklist"
	}
	else
 	{
		Write-Host "No existing DNS Blacklist found"
	}

	#Downloading of the Adblock reg file
	Write-Host "Downloading newest AdBlock file..."
	if (-not (Split-Path -parent $path) -or -not (Test-Path -pathType Container (Split-Path -parent $path)))
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
		throw "Download of the DNS Blacklist failed"
	}

	Write-Host "Detecting if new DNS Blacklist exists..."
	if (-Not(Test-Path $blacklist))
 	{
		throw "Download of the DNS Blacklist failed"
	}

	#Stopping the DNS Server
	Write-Host "Stopping DNS Server..."
	Stop-Service -Name DNS
	Write-Host "Stopped DNS Server"

	#Remove All Old Entries (CAUTION: Be sure to tweak this to your environment and not delete valid DNS entries)
	Write-Host "Deleting old Blacklist entries from Registry"
	Get-ChildItem "HKLM:\software\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones\" |
	ForEach-Object {

		$CurrentKey = Get-ItemProperty -Path $_.PsPath

		# Cleanly detect zones that are using adservers.dns
		if ($CurrentKey.PSObject.Properties.Name -icontains 'DatabaseFile' -and $CurrentKey.DatabaseFile -ieq $adServerZoneFile)
		{
			$CurrentKey | Remove-Item -Force # -Whatif
		}
	}

	Write-Host "Deleted old Blacklist entries from Registry"

	#Importing the file into regedit
	Write-Host "Importing AdBlock file..."
	regedit.exe /s $blacklist
	Write-Host "Imported AdBlock file"

	#Starting the DNS Server
	Write-Host "Starting DNS Server..."
	Start-Service -Name DNS
	Write-Host "Started DNS Server"

	#Removing Blacklist files older then 15 days
	Write-Host "Removing old AdBlock files..."
	Get-ChildItem -Path $path -Recurse -Force | Where-Object { -not $_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
	Write-Host "Removed old AdBlock files"

	#Script has been completed
	Write-Host "Script has been completed"
}
catch
{
	Write-Host -ForegroundColor Red $_.Exception.Message
	exit 1
}
