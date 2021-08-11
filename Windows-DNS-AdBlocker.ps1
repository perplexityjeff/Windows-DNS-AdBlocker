<#
    .SYNOPSIS
        Populate Windows DNS with entries for known ad-server domains to block them

    .DESCRIPTION
        Use DNS to block known ad-server domains by redirecting requests to localhost
        This needs to be run with administrator privilege, and if using Active Directory integration,
        you should run this under an account with domain admin privilege.

    .PARAMETER Remove
        If set, remove all ad-server entries from the DNS
        If not set, update DNS with latest ad-server entries.

    .PARAMETER ActiveDirectoryIntegrated
        If set, detect Active Directory and create AD integrated zones if found.
        Integrated zones will replicate to all DNS servers in AD forest.
#>
param
(
    [switch]$Remove,
    [switch]$ActiveDirectoryIntegrated
)

Write-Host "===================================================="
Write-Host "Windows-DNS-AdBlocker"
Write-Host "https://github.com/perplexityjeff/Windows-DNS-AdBlocker"
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
$artifactPath = Join-Path $env:TEMP "DNS Blocklist"
$url = "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=win32reg-sp4&showintro=0&mimetype=plaintext"
$adServerZoneFile = "adservers.dns"
$adserversurl = "https://raw.githubusercontent.com/perplexityjeff/Windows-DNS-AdBlocker/master/$adServerZoneFile"
$adserverstemp = Join-Path $artifactPath $adServerZoneFile
$adServersZoneFileLocation = Join-Path $env:SYSTEMROOT (Join-Path "System32\dns" $adServerZoneFile)

$date = Get-Date -format "yyyyMMdd"
$blocklist = Join-Path $artifactPath ("Blocklist_" + $date + ".reg")
$limit = (Get-Date).AddDays(-15)

# How we will identify Active Directory integrated zones created by this tool.
$responsiblePerson = "adserver-71e5831a-aba8-4890-9037-399cb92de586"

# Detect Active Directory and DnsServer PowerShell module
$useActiveDirectory = $false
$activeDirectoryDetected = $null -ne $env:LOGONSERVER -and $null -ne $env:USERDOMAIN
$haveDnsServerModule = $null -ne (Get-Module -ListAvailable DnsServer)

# This sets the security used in the WebClient to TLS 1.2, if it fails like on V2 it uses another method
try
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch
{
    $p = [Enum]::ToObject([System.Net.SecurityProtocolType], 3072);
    [System.Net.ServicePointManager]::SecurityProtocol = $p;
}

try
{
    # Test for admin rights
    if (-not (New-Object Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        throw "Must be Administrator to run this program."
    }

    # Test if DNS server exists on this host
    if (-not (Get-Service -Name DNS -ErrorAction SilentlyContinue))
    {
        throw "Local DNS server not found. Please run on a server that hosts DNS."
    }

    if (-not ([Environment]::UserInteractive))
    {
        # Hide progress bars if running e.g. in task scheduler.
        $ProgressPreference = 'SilentlyContinue'
    }

    if ($haveDnsServerModule)
    {
        # For Windows 2012 and above, use DnsServer cmdlets
        Write-Host "Importing DnsServer module"
        Import-Module DnsServer
    }

    if ($activeDirectoryDetected -and $haveDnsServerModule -and ([Environment]::UserInteractive) -and -not ($ActiveDirectoryIntegrated -or $Remove))
    {
        # Recommend AD integration if not selected.
        $choice = $host.ui.PromptForChoice(
            "Active Directory detected. It is recommended to use it as it will replicate zones to all DNS servers in the forest. Use Active Directory?",
            $null,
            @(
                New-Object System.Management.Automation.Host.ChoiceDescription ('&Yes', "Use Active Directory." )
                New-Object System.Management.Automation.Host.ChoiceDescription ('&No', 'Use file-based zones (no replication).')
            ),
            0
        )

        if ($choice -eq 0)
        {
            $useActiveDirectory = $true
        }
    }

    if ($ActiveDirectoryIntegrated)
    {
        # If user asked for Active Directory integration, check we can actually do it.
        if (-not $activeDirectoryDetected)
        {
            Write-Warning "Active Directory domain not detected, or you are not using a domain login. Falling back to file-based zones"
        }
        else
        {
            # Check we have the required PowerShell module for integration
            if ($haveDnsServerModule)
            {
                $useActiveDirectory = $true
            }
            else
            {
                Write-Warning "PowerShell module DnsServer not detected. Cannot use AD integration. Perhaps this version of Windows is too old. Falling back to file-based zones"
            }
        }
    }

    if ($Remove)
    {
        Write-Host "Removing ad-block entries from DNS only."
    }
    else
    {
        # Testing if DNS Blocklist folder exists
        Write-Host "Detecting if download location exists..."
        if (Test-Path $artifactPath)
        {
            Write-Host "Download location exists"
        }
        else
        {
            New-Item $artifactPath -ItemType directory
            Write-Host "Download location has been created"
        }

        # Testing if $adServerZoneFile file exists
        Write-Host "Detecting if $adServerZoneFile file exists..."
        if (-not (Test-Path $adServersZoneFileLocation))
        {
            Write-Host "Downloading default $adServerZoneFile file..."
            $client = new-object System.Net.WebClient

            try
            {
                $client.DownloadFile($adserversurl, $adserverstemp)
            }
            finally
            {
                if ($client)
                {
                    $client.Dispose()
                }
            }

            Write-Host "Downloaded default $adServerZoneFile file"

            Write-Host "Placing downloaded $adServerZoneFile file in the systemroot..."
            Move-Item $adserverstemp $adServersZoneFileLocation
            Write-Host "Placed downloaded $adServerZoneFile file in the systemroot"
        }
        else
        {
            Write-Host "Detected $adServerZoneFile file"
        }

        # Testing if DNS Blocklist exists
        Write-Host "Detecting if older DNS Blocklist exists..."
        if (Test-Path $blocklist)
        {
            Write-Host "Deleting old DNS Blocklist..."
            Remove-Item ($blocklist)
            Write-Host "Deleted old DNS Blocklist"
        }
        else
        {
            Write-Host "No existing DNS Blocklist found"
        }

        # Downloading of the Adblock reg file
        Write-Host "Downloading newest AdBlock file..."
        if (-not (Split-Path -parent $artifactPath) -or -not (Test-Path -pathType Container (Split-Path -parent $artifactPath)))
        {
            $artifactPath = Join-Path $pwd (Split-Path -leaf $artifactPath)
        }
        try
        {
            $client = new-object System.Net.WebClient

            try
            {
                $client.DownloadFile($url, $blocklist)
            }
            finally
            {
                if ($client)
                {
                    $client.Dispose()
                }
            }

            Write-Host "Downloaded newest AdBlock file"
        }
        catch
        {
            throw "Download of the DNS Blocklist failed"
        }

        Write-Host "Detecting if new DNS Blocklist exists..."
        if (-Not(Test-Path $blocklist))
        {
            throw "Download of the DNS Blocklist failed"
        }
    }

    if (-not $haveDnsServerModule)
    {
        # With DnsServer PowerShell module, we can operate on the DNS hot.
        # If poking the registry, we need to do it cold.
        # Stopping the DNS Server.
        Write-Host "Stopping DNS Server..."
        Stop-Service -Name DNS
        Write-Host "Stopped DNS Server"
    }

    # Remove All Old Entries (CAUTION: Be sure to tweak this to your environment and not delete valid DNS entries)
    Write-Host "Deleting old Blocklist entries"
    $zoneKey = "HKLM:\software\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones\"

    # Read all zones _before_ modifying anything
    if ($haveDnsServerModule)
    {
        # We can do some pre-filtering here
        $allZones = Get-DnsServerZone | Where-Object { $_.ZoneType -eq 'Primary' -and -not $_.IsReverseLookupZone -and -not $_.IsAutoCreated }
    }
    else
    {
        $allZones = (Get-ChildItem -Path $zoneKey).Name |
        Split-Path -Leaf |
        ForEach-Object {

            # Make these results look like a DNS Zone object returned by Get-DnsZerverZone
            New-Object PSObject -Property @{
                ZoneName = $_
            }
        }
    }

    # Further filter out zones matching the the user DNS domain and the TrustAnchors special domain
    $allZones = $allZones |
    Where-Object {

        $_.ZoneName -ne 'TrustAnchors'
    } |
    Where-Object {

        if ($null -eq $env:USERDNSDOMAIN)
        {
            # Include all if no DNS domain to compare with
            $true
        }
        else
        {
            # Include those not matching the local DNS domain
            -not $_.ZoneName.EndsWith($env:USERDNSDOMAIN, [StringComparison]::OrdinalIgnoreCase)
        }
    }

    # Now do the deletions
    # Use Measure-Object as it can count the input object being $null
    $totalZones = ($allZones | Measure-Object).Count
    $numRemoved = 0
    $numProcessed = 0

    $allZones |
    ForEach-Object {

        if ($numRemoved % 20 -eq 0)
        {
            # Update progress every 20 zones
            $percentComplete = [int](($numProcessed / $totalZones) * 100)
            Write-Progress -Activity "Deleting adserver DNS zones" -Status "$($percentComplete)% Complete:" -PercentComplete $percentComplete
        }

        if ($haveDnsServerModule)
        {
            $zone = Get-DnsServerZone -Name $_.ZoneName -ErrorAction SilentlyContinue

            if ($null -ne $zone)
            {
                # Is it one of ours?
                if ($zone.IsDsIntegrated)
                {
                    # AD Integrated - Identify by the value we set for Responsible Person in the SOA record...

                    # Get SOA record
                    $soa = $zone | Get-DnsServerResourceRecord -RRType SOA

                    if ($soa.RecordData.ResponsiblePerson.StartsWith($responsiblePerson))
                    {
                        # Delete it.
                        Write-Verbose "Removing zone: $($_.ZoneName)"
                        $zone | Remove-DnsServerZone -Force
                        ++$numRemoved
                    }
                }
                else
                {
                    # File zone - Identify by the zone filename
                    if ($zone.ZoneFile -eq $adServerZoneFile)
                    {
                        # Delete it.
                        Write-Verbose "Removing zone: $($_.ZoneName)"
                        $zone | Remove-DnsServerZone -Force
                        ++$numRemoved
                    }
                }
            }

            ++$numProcessed
        }
        else
        {
            $CurrentKey = Get-ItemProperty -Path (Join-Path $zoneKey $_.ZoneName)

            # Cleanly detect zones that are using adservers.dns
            if ($CurrentKey.PSObject.Properties.Name -icontains 'DatabaseFile' -and $CurrentKey.DatabaseFile -ieq $adServerZoneFile)
            {
                Write-Verbose "Removing zone: $($CurrentKey.PSChildName)"
                $CurrentKey | Remove-Item -Force #-Whatif
                ++$numRemoved
            }
        }
    }

    # Import new adserver zones

    # Clear progress bar
    Write-Progress -Activity "Deleting adserver DNS zones" -Status "100% Complete:" -PercentComplete 100 -Completed
    Write-Host "Deleted $numRemoved old Blocklist entries from Registry"

    if (-not $Remove)
    {
        Write-Host "Importing AdBlock file..."

        if ($haveDnsServerModule)
        {
            $numAdded = 0

            # Parse the REG file for domains and add them
            $domains = Get-Content $blocklist |
            Foreach-Object {

                if ($_ -match '\\(?<domain>[^\\]+)\]\s*$')
                {
                    $Matches.domain
                }
            }

            $totalZones = ($domains | Measure-Object).Count

            $domains |
            Foreach-Object {

                if ($numAdded % 20 -eq 0)
                {
                    # Update progress every 20 zones
                    $percentComplete = [int](($numAdded / $totalZones) * 100)
                    Write-Progress -Activity "Adding adserver DNS zones" -Status "$($percentComplete)% Complete:" -PercentComplete $percentComplete
                }

                if ($useActiveDirectory)
                {
                    # Create Active Directory integrated zone and add records to block
                    # Set the responsible person field in the SOA record to our magic value for easy indentification on delete.
                    $zone = Add-DnsServerPrimaryZone -Name $_ -ResponsiblePerson $responsiblePerson -ReplicationScope Forest -PassThru
                    $zone | Add-DnsServerResourceRecordA -IPv4Address 0.0.0.0 -Name '*' -TimeToLive 01:00:00
                    $zone | Add-DnsServerResourceRecordA -IPv4Address 0.0.0.0 -Name '@' -TimeToLive 01:00:00
                }
                else
                {
                    # Create zone and point to our zone file
                    Add-DnsServerPrimaryZone -Name $_ -ZoneFile $adServerZoneFile -LoadExisting -ResponsiblePerson $responsiblePerson
                }

                ++$numAdded
            }

            # Clear progress bar
            Write-Progress -Activity "Adding adserver DNS zones" -Status "100% Complete:" -PercentComplete 100 -Completed
            Write-Host "Imported $numAdded zones from AdBlock file"
        }
        else
        {
            # Importing the file into regedit
            "REGEDIT4`n" | Insert-Content $blocklist
            regedit.exe /s $blocklist
            Write-Host "Imported AdBlock file"
        }
    }

    if ((Get-Service -Name DNS).Status -ne 'Running')
    {
        # Starting the DNS Server
        Write-Host "Starting DNS Server..."
        Start-Service -Name DNS
        Write-Host "Started DNS Server"
    }

    #Removing Blocklist files older then 15 days
    Write-Host "Removing old AdBlock files..."
    Get-ChildItem -Path $artifactPath -Recurse -Force | Where-Object { -not $_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
    Write-Host "Removed old AdBlock files"

    #Script has been completed
    Write-Host "Script has been completed"
}
catch
{
    Write-Host -ForegroundColor Red $_.Exception.Message
    exit 1
}
