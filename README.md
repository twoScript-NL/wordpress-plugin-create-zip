# wordpress-plugin-create-zip
Windows PowerShell script to create an installable zip file for your Wordpress plugin excluding unnessecery files and folders.

---

## Step 1
7-Zip is required for this file to work

---

## Step 2
Set the excludes files and folders in $excludes 

---

## Step 3
Place the create-plugin-zip.ps1 in the plugin folder

---

## Step 4
To exectute file go to Windows PowerShell with as an admin  
`.\create-plugin-zip.ps1 -plugin_version "1.0.0"`