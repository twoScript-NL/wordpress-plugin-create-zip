# Always use current folder as plugin dir
$PluginDir = (Get-Location).Path

# Find main plugin file
$phpFiles = Get-ChildItem -Path $PluginDir -Filter "*.php" -File

$MainPluginFile = $null
$plugin_name = $null
$content = $null

foreach ($file in $phpFiles) {

    # Read only first 50 lines (faster + safer)
    $head = Get-Content $file.FullName -TotalCount 50 | Out-String

    if ($head -match '(?m)^\s*\*?\s*Plugin Name:\s*(.+)$') {
        $MainPluginFile = $file.FullName
        $plugin_name = $matches[1].Trim()
        $content = Get-Content $file.FullName -Raw
        break
    }
}

if (-not $MainPluginFile) {
    Write-Host "Error: Could not find main plugin file (Plugin Name header missing)."
    exit 1
}

Write-Host "Detected main plugin file: $MainPluginFile"
Write-Host "Detected plugin name: $plugin_name"


$content = Get-Content $MainPluginFile -Raw

# Get version from header if not provided
if ($content -match '(?m)^\s*\*?\s*Version:\s*([0-9A-Za-z._-]+)') {
    $plugin_version = $matches[1]
    Write-Host "Detected plugin version: $plugin_version"
} else {
    Write-Host "Error: Could not find Version header."
    exit 1
}


# Determine plugin base folder name
# Prefer Text Domain if available (WordPress standard)
if ($content -match '(?m)^\s*\*?\s*Text Domain:\s*(.+)$') {
    $PluginBaseName = $matches[1].Trim()
    Write-Host "Using Text Domain as folder name: $PluginBaseName"
} else {
    # fallback → slugify plugin name
    $PluginBaseName = ($plugin_name -replace '[^a-zA-Z0-9]+','_').ToLower()
    Write-Host "Using generated folder name: $PluginBaseName"
}

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
if (Test-Path "zip\$ZipName") {
    Write-Host "Removing existing ZIP file: $ZipName"
    Remove-Item "zip\$ZipName"
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
    "gulpfile.js",
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
