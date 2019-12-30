# Windows-DNS-AdBlocker

A simple to use PowerShell script that uses an open source adblocking list and imports it into the Windows Server DNS entry list to block them. To be used as a scheduled task to run and update entries. I suggest running it every weekend.

For Windows 2012 Server and above, this script uses the `DnsServer` PowerShell module to make changes to the DNS, and if Active Directory is detected then it can create AD-integrated DNS zones that will replicate forest-wide. For earlier versions of Windows, only the local DNS will be updated via direct modification of the registry - if you have more than one DNS server you will need to run this script at all of them.

We installed this script as a security measure and to ease deployment for all users that do not have the required rights to install an adblocker or the knowledge to do so when they want to. This way the DNS server controls everything and no need for per client installation or management.

## Caution

Use at your own risk! Be sure to thoroughly test before letting loose in any kind of corporate infrastructure!

There is code included to clean up the registry of old DNS entries to keep the AdBlock list up to date. This should be OK as it explicitly checks for existence of the property `DatabaseFile` having a value of `adservers.dns` on each zone entry but be sure to test it first, having a backup of your valid zones!

Where Active Directory integration is used, the `Responsible Person` field of the SOA record is set to a GUID value that is checked for on deletion, so should in theory be very safe.

## Tested

The script has been tested in our own environment (company-wide) on a Windows Server 2008 R2 / 2016 DNS machine but the script is flexible enough to work for the newer Operating Systems as well you need to do some edits mainly to the AdBlock list.

## AdBlock List

The script currently uses a very specific AdBlock list from https://pgl.yoyo.org/adservers/ they also have a great explanation about how to setup a Windows DNS AdBlocker on the website on this page https://pgl.yoyo.org/adservers/#other and navigating to the "Microsoft DNS Server" section. You will want to read it because you may require some pre-setup before the script can run fully automated.

Currently in the script we are using this specific AdBlock file:
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=win32reg-sp4&showintro=0&mimetype=plaintext

## Adservers.dns file

The file included in this repo called `adservers.dns` is a file that should be copied to `%SystemRoot%\system32\dns` as a reference of where the entry detected needs to go when a ad has been detected. The one that I added routes everything to localhost making them not appear but you could customize this. The script automatically downloads the default `adservers.dns` file when has detected it is not found.

This file is used only for non-Active Directory integrated deployments. For AD-integrated mode, the default A record entries are pointed to the same location (localhost) as that in `adservers.dns`. Currently, if you wish to change this you will need to edit the code.

## Cleaning up

If you want to remove all the adblock zones from your DNS, run this script again with the `-Remove` switch. Please pay attention to the `Caution` paragraph above, especially if you have created the zones in non-Active Directory integrated mode.

## License

This project is licensed under the [MIT license](LICENSE)

## Learning

I am still a beginner in PowerShell and I am learning it through my work as I need to get things done so please be kind to me when you see any weird mistakes or things in the script. I hope it helps someone somewhere :D !
