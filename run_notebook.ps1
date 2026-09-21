# Run from PowerShell. The notebook also opens directly in JupyterLab or VS Code.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
python -m jupyterlab DPS_QKD_model.ipynb
