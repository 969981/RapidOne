#requires -Version 5.1
<#
.SYNOPSIS
  Convert a RapidOne Windows MSI into an extract-and-run ZIP without installing it.
.DESCRIPTION
  msiexec /a performs administrative extraction, NOT a normal installation.
  This works with an official MSI or one built by this fork.
  Portable launcher redirects environment-aware app/runtime caches into Data.
  Native Tauri known-folder paths and the upstream private plugins may still
  use Windows profile locations unless built with explicit portable support.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MsiPath,
    [Parameter(Mandatory=$true)][string]$Version,
    [string]$OutputDir = "."
)
$ErrorActionPreference = 'Stop'
$msi = (Resolve-Path -LiteralPath $MsiPath).Path
$output = [IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Path $output -Force | Out-Null

$work = Join-Path $env:TEMP ("rapidone-portable-" + [Guid]::NewGuid().ToString('N'))
$unpacked = Join-Path $work 'unpacked'
$staged = Join-Path $work 'RapidOne-Portable'
New-Item -ItemType Directory -Path $unpacked,$staged -Force | Out-Null
$log = Join-Path $work 'msiexec.log'
try {
    Write-Host "Extracting MSI without installing: $msi"
    $arguments = "/a `"$msi`" /qn TARGETDIR=`"$unpacked`" /L*v `"$log`""
    $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -PassThru -Wait -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        if (Test-Path $log) { Get-Content $log -Tail 70 | Write-Host }
        throw "MSI administrative extraction failed with exit code $($proc.ExitCode)"
    }

    $executables = @(Get-ChildItem -Path $unpacked -Recurse -File -Filter 'RapidOne.exe')
    if ($executables.Count -ne 1) {
        throw "Expected one RapidOne.exe in MSI extraction, found $($executables.Count)"
    }
    $appDir = $executables[0].Directory.FullName
    Write-Host "Executable located at $appDir"
    Copy-Item -Path (Join-Path $appDir '*') -Destination $staged -Recurse -Force

    # No registry or system directory changes are made by this ZIP.
    New-Item -ItemType File -Path (Join-Path $staged 'portable.flag') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $staged 'Data') -Force | Out-Null

    $launcher = @'
@echo off
setlocal
cd /d "%~dp0"
set "RAPIDONE_PORTABLE_ROOT=%~dp0Data"
set "APPDATA=%~dp0Data\Roaming"
set "LOCALAPPDATA=%~dp0Data\Local"
set "HOME=%~dp0Data\Home"
set "XDG_CACHE_HOME=%~dp0Data\Cache"
set "XDG_CONFIG_HOME=%~dp0Data\Config"
set "XDG_DATA_HOME=%~dp0Data\Share"
set "UV_CACHE_DIR=%~dp0Data\Cache\uv"
set "UV_PYTHON_INSTALL_DIR=%~dp0Data\Python"
set "PIP_CACHE_DIR=%~dp0Data\Cache\pip"
set "HF_HOME=%~dp0Data\Cache\huggingface"
set "PYTHONUSERBASE=%~dp0Data\PythonUser"
set "TEMP=%~dp0Data\Temp"
set "TMP=%~dp0Data\Temp"
for %%D in ("%APPDATA%" "%LOCALAPPDATA%" "%HOME%" "%UV_CACHE_DIR%" "%UV_PYTHON_INSTALL_DIR%" "%TEMP%" "%HF_HOME%" "%PIP_CACHE_DIR%" "%PYTHONUSERBASE%") do if not exist "%%~D" mkdir "%%~D"
if not exist "%~dp0RapidOne.exe" (
  echo RapidOne.exe not found. Keep the extracted files together.
  pause
  exit /b 1
)
start "" /wait "%~dp0RapidOne.exe" %*
'@
    [IO.File]::WriteAllText((Join-Path $staged 'Start-RapidOne-Portable.cmd'),
        $launcher.Replace("`n","`r`n"),[Text.Encoding]::ASCII)

    $readme = @'
RapidOne Windows Portable (x64)
================================
Launch: Start-RapidOne-Portable.cmd
Do not run the MSI installer. Extract this ZIP to a writable folder such as
D:\Apps\RapidOne-Portable (avoid Program Files).

Data\ stores environment-aware settings/cache/model bootstrap data.
The native fork source also supports portable.flag for RapidOne-owned:
  Data\Roaming\com.chriscork.rapidone\presets and styles
  Data\Local\com.chriscork.rapidone\lensfun
  Data\Documents\RapidOne\Profiles

IMPORTANT: When packaged from official crispin81/RapidOne v1.2.1 binaries,
the original executable does NOT include the fork's native portable path changes.
Changing APPDATA/LOCALAPPDATA/HOME in this launcher does not guarantee all
Tauri and Windows known-folder writes are redirected. Retouch/Cull private
modules also have unverified storage paths. This archive is INSTALL-FREE,
but NOT guaranteed to be 100% data-portable until rebuilt and verified.

RapidOne deliberately stores .rpd photo edits and some caches in a sidecars/
folder next to the original photos. This launcher does not migrate or override
those files; keep your photo folders if you need their editing history.

A compatible Microsoft Edge WebView2 Runtime is required by Tauri on Windows.
Some Windows installations already have it; this ZIP does not install it.
Do not launch from inside a ZIP or a read-only directory.
'@
    [IO.File]::WriteAllText((Join-Path $staged 'PORTABLE-README.txt'),
        $readme.Replace("`n","`r`n"),[Text.Encoding]::UTF8)

    $zip = Join-Path $output "RapidOne_${Version}_windows_x64_portable.zip"
    if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
    Write-Host "Creating $zip"
    Compress-Archive -Path (Join-Path $staged '*') -DestinationPath $zip -CompressionLevel Optimal
    if (!(Test-Path $zip) -or (Get-Item $zip).Length -lt 1000000) {
        throw 'Portable archive is missing or unexpectedly small'
    }
    Write-Host "Portable ZIP completed: $zip"
}
finally {
    if (Test-Path $work) { Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue }
}
