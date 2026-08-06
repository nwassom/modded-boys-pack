param(
    [string]$InstanceDir = $env:INST_DIR,
    [string]$JavaExe = $env:INST_JAVA
)

$ErrorActionPreference = "Stop"

# Allow the script to be run manually from minecraft/tools.
if ([string]::IsNullOrWhiteSpace($InstanceDir)) {
    $minecraftDir = Split-Path $PSScriptRoot -Parent
    $InstanceDir = Split-Path $minecraftDir -Parent
}

$instanceConfig = Join-Path $InstanceDir "instance.cfg"

if (-not (Test-Path $instanceConfig)) {
    Write-Error "Could not find Prism instance config: $instanceConfig"
    exit 2
}

# Confirm that the selected Java runtime supports ZGC before enabling it.
if (-not [string]::IsNullOrWhiteSpace($JavaExe) -and (Test-Path $JavaExe)) {
    & $JavaExe -XX:+UseZGC -version *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "The selected Java runtime does not support ZGC." -ForegroundColor Red
        Write-Host "Enable Prism's automatic Java 17 management, then launch again."
        exit 3
    }
}

$original = [System.IO.File]::ReadAllText($instanceConfig)
$updated = $original

$desiredSettings = [ordered]@{
    "OverrideJavaArgs" = "true"
    "JvmArgs"          = "-XX:+UseZGC -XX:+DisableExplicitGC"
}

foreach ($setting in $desiredSettings.GetEnumerator()) {
    $pattern = "(?m)^" + [regex]::Escape($setting.Key) + "=.*$"
    $replacement = "$($setting.Key)=$($setting.Value)"

    if ([regex]::IsMatch($updated, $pattern)) {
        $updated = [regex]::Replace(
            $updated,
            $pattern,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($match)
                return $replacement
            },
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
    [System.IO.File]::WriteAllText($instanceConfig, $updated, $utf8)

    Write-Host ""
    Write-Host "Updated this Prism instance to use Java 17 ZGC." -ForegroundColor Green
    Write-Host "Launch the instance again to apply the new JVM settings."
    exit 42
}

exit 0
