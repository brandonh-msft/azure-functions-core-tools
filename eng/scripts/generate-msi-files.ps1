param (
    [string]$artifactsPath,
    [string]$runtime
)

# Resource directory is one level up from the script location
$resourceDir = Join-Path $PSScriptRoot "..\res\msi"

# Determine artifacts path - use parameter if provided, otherwise calculate from script location
if (-not $artifactsPath) {
    $rootDir = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $artifactsPath = "$rootDir\artifacts"
}

Write-Host "Generating MSI files"
Write-Host "Resource directory: $resourceDir"
Write-Host "Artifacts path: $artifactsPath"

# Add WiX to PATH
if (-not (@($env:Path -split ";") -contains $env:WIX)) {
    if ((Split-Path $env:WIX -Leaf) -ne "bin")
    {
        $env:Path += ";$env:WIX\bin"
    } else
    {
        $env:Path += ";$env:WIX"
    }
}

# Define default platforms
$defaultPlatforms = @('x64', 'x86')

# Determine platforms based on runtime or fallback to default
if ([string]::IsNullOrWhiteSpace($runtime)) {
    $platforms = $defaultPlatforms
    Write-Host "No runtime specified, using default platforms: $($platforms -join ', ')"
} else {
    switch -Regex ($runtime) {
        'win-x64' { $platforms = @('x64') }
        'win-x86' { $platforms = @('x86') }
        'win-arm64' {
            Write-Host "Skipping MSI generation for ARM64 platform."
            return
        }
        default {
            Write-Warning "Unsupported or unknown runtime '$runtime', using default platforms"
            $platforms = $defaultPlatforms
        }
    }
    Write-Host "Runtime '$runtime' mapped to platform(s): $($platforms -join ', ')"
}

# Get runtime version by finding func.dll
Write-Host "Searching for func.dll in $artifactsPath..."
$funcDlls = Get-ChildItem -Path $artifactsPath -Filter "func.dll" -Recurse -ErrorAction Continue

if ($funcDlls.Count -eq 0) {
    Write-Host "ERROR: No func.dll files found. Check the path or file name." -ForegroundColor Red
    exit 1
}

$cli = ""

Write-Host "Found $($funcDlls.Count) func.dll files"
foreach ($dll in $funcDlls) {
    $path = $dll.FullName

    # Check if this is the root func.dll and not in inproc folders
    if ((-not $path.Contains("in-proc6")) -and (-not $path.Contains("in-proc8"))) {
        $cli = $path
        break
    }
}

if (-not $cli) {
    $cli = $funcDlls[0].FullName  # Fallback to first dll found
}

$cliVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($cli).FileVersion
$buildNumberForZipFile = ($cliVersion -split "\.")[2]

Write-Host "CLI version: $cliVersion"
Write-Host "Build number: $buildNumberForZipFile"
Write-Host "##vso[task.setvariable variable=BuildNumberForZipFile;]$buildNumberForZipFile"

# Function to process MSI generation for a platform
function New-PlatformMSI {
    param(
        [string]$TargetDir,
        [string]$Platform,
        [string]$CliVersion,
        [string]$ResourceDir,
        [string]$ArtifactsPath
    )

    Write-Host "Processing platform: $Platform in directory: $TargetDir"

    # Copy required files
    $filesToCopy = @("icon.ico", "license.rtf", "installbanner.bmp", "installdialog.bmp")
    foreach ($file in $filesToCopy) {
        $sourcePath = "$resourceDir\$file"
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath -Destination $TargetDir
        } else {
            Write-Warning "File not found: $sourcePath"
        }
    }

    $currentLocation = Get-Location
    Set-Location $TargetDir

    try {
        $masterWxsName = "funcinstall"
        $fragmentName = "$Platform-frag"
        $msiName = "func-cli-$CliVersion-$Platform"

        $masterWxsPath = "$resourceDir\$masterWxsName.wxs"
        $fragmentPath = "$resourceDir\$fragmentName.wxs"
        $msiPath = "$artifactsPath\$msiName.msi"

        # Generate WiX fragment
        & { heat dir '.' -cg FuncHost -dr INSTALLDIR -gg -ke -out $fragmentPath -srd -sreg -template fragment -var var.Source }

        # Compile WiX sources
        & { candle -arch $Platform -dPlatform="$Platform" -dSource='.' -dProductVersion="$CliVersion" $masterWxsPath $fragmentPath }

        # Link to create MSI
        & { light -ext "WixUIExtension" -out $msiPath -sice:"ICE61" "$masterWxsName.wixobj" "$fragmentName.wixobj" }

        # Verify MSI was created
        if (-not (Test-Path -Path $msiPath)) {
            throw "$msiPath not found."
        }

        Write-Host "Successfully created: $msiPath"

    } finally {
        Set-Location $currentLocation
    }
}

# Process directories - handle both old and new directory naming conventions
$processedPlatforms = @()

# First, try new naming convention (Cli.win-x64, Cli.win-x86)
Get-ChildItem -Path $artifactsPath -Directory | ForEach-Object {
    $subDir = $_.FullName
    $matchedPlatform = $null

    foreach ($platform in $platforms) {
        if ($subDir -like "*Cli.win-$platform*") {
            $matchedPlatform = $platform
            break
        }
    }

    if ($matchedPlatform) {
        New-PlatformMSI -TargetDir $subDir -Platform $matchedPlatform -CliVersion $cliVersion -ResourceDir $resourceDir -ArtifactsPath $artifactsPath
        $processedPlatforms += $matchedPlatform
    }
}

# If no directories found with new convention, try old convention (win-x64, win-x86)
if ($processedPlatforms.Count -eq 0) {
    Write-Host "No directories found with new naming convention, trying old convention..."

    foreach ($platform in $platforms) {
        $targetDir = "$artifactsPath\win-$platform"
        if (Test-Path $targetDir) {
            New-PlatformMSI -TargetDir $targetDir -Platform $platform -CliVersion $cliVersion -ResourceDir $resourceDir -ArtifactsPath $artifactsPath
            $processedPlatforms += $platform
        }
    }
}

if ($processedPlatforms.Count -eq 0) {
    Write-Host "ERROR: No platform directories found. Expected directories like 'win-x64', 'win-x86' or '*Cli.win-x64*', '*Cli.win-x86*'" -ForegroundColor Red
    exit 1
}

Write-Host "MSI generation completed for platforms: $($processedPlatforms -join ', ')"