# Windows-DNS-AdBlocker

A simple to use PowerShell script that uses an adblocking list and imports it into the Windows Server DNS entry list to block them. To be used as a scheduled task to run and update entries. I suggest running it every weekend.

# Tested

The script has been tested in our own environment (company-wide) on a Windows Server 2008 R2 DNS machine but the script is flexible enough to work for the newer Operating Systems as well you need to do some edits mainly to the AdBlock list. 

# AdBlock List

The script currently uses a very specific AdBlock list from https://pgl.yoyo.org/adservers/ they also have a great explanation about how to setup a Windows DNS AdBlocker on the website on this page https://pgl.yoyo.org/adservers/#other and nagivating to the "Microsoft DNS Server" section.

Currently in the script we are using this specific AdBlock file:
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=win32reg-sp4&showintro=0&mimetype=plaintext
