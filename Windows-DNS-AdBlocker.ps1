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
    $client = new-object System.Net.WebClient 
    $client.DownloadFile($url, $blacklist) 
    "REGEDIT4`n" | Insert-Content $blacklist
    Write-Host "Downloaded newest AdBlock file"

    #Stopping the DNS Server
    Write-Host "Stopping DNS Server..."
    Get-Service | Where {$_.Name -Eq "DNS"} | Stop-Service
    Write-Host "Stopped DNS Server"

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