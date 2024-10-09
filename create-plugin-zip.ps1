param(
    [string]$plugin_version
)

# Variables
$PluginDir = ".\"  # Assume you run the script from within "twobuild"
$PluginBaseName = "pluginName"  # The base folder name for the plugin
$ZipName = "$PluginBaseName-v$plugin_version.zip"
$TempFolder = "$env:TEMP\wp_plugin_temp"

# Store the initial working directory
$InitialWorkingDirectory = Get-Location

if (-not $plugin_version) {
    Write-Host "Error: You must provide a plugin version using --plugin_version."
    exit 1
}

# Check if the plugin directory exists
if (-not (Test-Path $PluginDir)) {
    Write-Host "Error: Plugin directory '$PluginDir' does not exist."
    exit 1
}

# Remove the existing ZIP file if it exists
if (Test-Path $ZipName) {
    Write-Host "Removing existing ZIP file: $ZipName"
    Remove-Item $ZipName
}

# Create a temporary folder to hold the plugin
$TempPluginDir = "$TempFolder\$PluginBaseName"

# Remove the temp folder if it exists
if (Test-Path $TempFolder) {
    Remove-Item -Recurse -Force $TempFolder
}

# Create new temp plugin folder
New-Item -ItemType Directory -Path $TempPluginDir | Out-Null

# Define exclusions using wildcard patterns
$excludes = @(
    ".git*",
    "node_modules*",
    "idea*",
    "assets\scss*",
    "canvas_templates\*_canvas.json",
    "gulpfile.js",
    "output_gall_en_gall_274534.pdf",
    "twobuild.zip",
    "test.php",
    "create-plugin-zip.sh",
    "create-plugin-zip.ps1",
    "zip*"
)

# Function to check if a path matches any exclusion pattern
function IsExcluded {
    param (
        [string]$path
    )
    # Normalize path for comparison
    $normalizedPath = $path.Replace("/", "\").ToLower()
    foreach ($exclude in $excludes) {
        $wildcardPattern = $exclude.ToLower()
        if ($normalizedPath -like "*$wildcardPattern*") {
            return $true
        }
    }
    return $false
}

# Copy files and directories, excluding specified items
Get-ChildItem -Path $PluginDir -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring((Get-Item $PluginDir).FullName.Length).TrimStart("\")
    $destinationPath = Join-Path $TempPluginDir $relativePath

    # Skip excluded items based on pattern match
    if (-not (IsExcluded($relativePath))) {
        if ($_.PSIsContainer) {
            # Create directories
            if (-not (Test-Path $destinationPath)) {
                New-Item -ItemType Directory -Path $destinationPath | Out-Null
            }
        } else {
            # Copy files
            Copy-Item -Path $_.FullName -Destination $destinationPath
        }
    }
}

# Use 7-Zip to create the ZIP file, starting from the 'twobuild' directory level
$7zipPath = "C:\Program Files\7-Zip\7z.exe"
Write-Host "Creating ZIP file using 7-Zip: $ZipName"
Set-Location -Path $TempFolder

# Create the ZIP with the correct structure
Start-Process $7zipPath -ArgumentList "a", "-tzip", "`"$InitialWorkingDirectory\zip\$ZipName`"", "`"$PluginBaseName\*`"" -NoNewWindow -Wait

# Reset location back to the initial working directory
Set-Location -Path $InitialWorkingDirectory

# Give a brief delay before removing the temp folder to ensure all handles are released
Start-Sleep -Seconds 2

# Remove the temporary folder
Remove-Item -Recurse -Force $TempFolder

# Done
Write-Host "ZIP file created successfully: $ZipName"
