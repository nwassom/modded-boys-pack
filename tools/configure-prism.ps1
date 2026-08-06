param(
    [string]$InstanceDir = $env:INST_DIR,
    [string]$JavaExe = $env:INST_JAVA
)

$ErrorActionPreference = "Stop"

# Allow manual execution from minecraft/tools.
if ([string]::IsNullOrWhiteSpace($InstanceDir)) {
    $minecraftDir = Split-Path $PSScriptRoot -Parent
    $InstanceDir = Split-Path $minecraftDir -Parent
}

$instanceConfig = Join-Path $InstanceDir "instance.cfg"

if (-not (Test-Path $instanceConfig)) {
    Write-Error "Could not find Prism instance config: $instanceConfig"
    exit 2
}

# Test ZGC without letting java -version's stderr output become a
# PowerShell NativeCommandError.
if (
    -not [string]::IsNullOrWhiteSpace($JavaExe) -and
    (Test-Path $JavaExe)
) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $JavaExe
    $startInfo.Arguments = "-XX:+UseZGC -version"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    [void]$process.Start()

    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()

    $process.WaitForExit()
    $javaExitCode = $process.ExitCode
    $process.Dispose()

    if ($javaExitCode -ne 0) {
        Write-Host ""
        Write-Host "The selected Java runtime does not support ZGC." `
            -ForegroundColor Red

        if (-not [string]::IsNullOrWhiteSpace($standardError)) {
            Write-Host $standardError
        }

        Write-Host "Select a compatible 64-bit Java 17 runtime in Prism."
        exit 3
    }

    Write-Host "Java runtime supports ZGC." -ForegroundColor Green
}

$original = [System.IO.File]::ReadAllText($instanceConfig)
$updated = $original

$desiredSettings = [ordered]@{
    "OverrideJavaArgs" = "true"
    "JvmArgs" = "-XX:+UseZGC -XX:+DisableExplicitGC"
}

foreach ($setting in $desiredSettings.GetEnumerator()) {
    $pattern = "(?m)^" + [regex]::Escape($setting.Key) + "=.*$"
    $replacement = "$($setting.Key)=$($setting.Value)"

    if ([regex]::IsMatch($updated, $pattern)) {
        $updated = [regex]::Replace(
            $updated,
            $pattern,
            $replacement,
            1
        )
    }
    else {
        if (-not $updated.EndsWith("`n")) {
            $updated += "`r`n"
        }

        $updated += "$replacement`r`n"
    }
}

if ($updated -ne $original) {
    $backup = "$instanceConfig.before-modded-boys-gc"

    if (-not (Test-Path $backup)) {
        Copy-Item $instanceConfig $backup -Force
    }

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        $instanceConfig,
        $updated,
        $utf8
    )

    Write-Host ""
    Write-Host "Configured this Prism instance to use ZGC." `
        -ForegroundColor Green
    Write-Host "Launch the instance again to apply the new JVM settings."

    # Stop this launch because Prism already selected the old JVM
    # arguments before running the pre-launch command.
    exit 42
}

Write-Host "Prism ZGC settings are already configured." `
    -ForegroundColor Green

exit 0
