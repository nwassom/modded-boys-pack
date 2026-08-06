$ErrorActionPreference = "Stop"

$packUrl = "https://nwassom.github.io/modded-boys-pack/pack.toml"
$bootstrap = Join-Path $env:INST_MC_DIR "packwiz-installer-bootstrap.jar"
$configurator = Join-Path $env:INST_MC_DIR "tools\configure-prism.ps1"

if (-not (Test-Path $bootstrap)) {
    Write-Error "Missing Packwiz bootstrap: $bootstrap"
    exit 2
}

# Update the modpack first, including the latest configuration script.
& $env:INST_JAVA -jar $bootstrap $packUrl

if ($LASTEXITCODE -ne 0) {
    Write-Error "Packwiz update failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

if (-not (Test-Path $configurator)) {
    Write-Error "Missing Prism configuration script: $configurator"
    exit 3
}

& $configurator `
    -InstanceDir $env:INST_DIR `
    -JavaExe $env:INST_JAVA

$configExitCode = $LASTEXITCODE

# Abort this launch once if instance.cfg was changed.
# Prism will read the new JVM settings on the next launch.
if ($configExitCode -eq 42) {
    exit 1
}

exit $configExitCode
