# Windows-DNS-AdBlocker

A simple to use PowerShell script that uses an adblocking list and imports it into the Windows Server DNS entry list to block them. To be used as a scheduled task to run and update entries. I suggest running it every weekend.

We installed this script as a security measure and to ease deployment for all users that do not have the required rights to install an adblocker or the knowledge to do so when they want to. This way the DNS server controls everything and no need for per client installation or management.

## Caution

There is code included to clean up the registry of old DNS entries. This needs to be tweaked to your environment as it is will otherwise delete valid DNS entries. Be sure to check and test everything before deployment. 

## Tested

The script has been tested in our own environment (company-wide) on a Windows Server 2008 R2 DNS machine but the script is flexible enough to work for the newer Operating Systems as well you need to do some edits mainly to the AdBlock list. 

## AdBlock List

The script currently uses a very specific AdBlock list from https://pgl.yoyo.org/adservers/ they also have a great explanation about how to setup a Windows DNS AdBlocker on the website on this page https://pgl.yoyo.org/adservers/#other and nagivating to the "Microsoft DNS Server" section. You will want to read it because you will require some pre-setup before the script can run fully automated. 

Currently in the script we are using this specific AdBlock file:
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=win32reg-sp4&showintro=0&mimetype=plaintext

The file included in this repo called adservers.dns is a file that is copied to %SystemRoot%\system32\dns as a reference of where the entry detected needs to go when a ad has been detected. The one that I added routes everything to localhost making them not appear but you could customize this.

## Learning

I am still a beginner in PowerShell and I am learning it through my work as I need to get things done so please be kind to me when you see any weird mistakes or things in the script. I hope it helps someone somewhere :D !
