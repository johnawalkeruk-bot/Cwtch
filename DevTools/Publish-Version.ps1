param([string]$Version)
$python=Join-Path (Split-Path $PSScriptRoot) 'Launcher/Python/python.exe'
if ($Version) { & $python (Join-Path $PSScriptRoot 'publish.py') --version $Version }
else { & $python (Join-Path $PSScriptRoot 'publish.py') }
if ($LASTEXITCODE -ne 0) { throw 'Publishing stopped. Review the output above.' }
