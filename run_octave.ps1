# Use the installed Qt executable for interactive parameter tables and charts.
$ErrorActionPreference = 'Stop'
$dpsOctaveExe = 'D:\AntennaSimulations\Octave-10.3.0\mingw64\bin\octave-gui.exe'
if (-not (Test-Path -LiteralPath $dpsOctaveExe)) {
    throw "Octave was not found at $dpsOctaveExe. Update this launcher path."
}
Set-Location -LiteralPath $PSScriptRoot
& $dpsOctaveExe --persist --eval "addpath(pwd); dps_qkd_simulator();"
