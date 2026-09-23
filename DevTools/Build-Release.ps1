param([Parameter(Mandatory=$true)][string]$Version)
$python=Join-Path (Split-Path $PSScriptRoot) 'Launcher/Python/python.exe'
& $python (Join-Path $PSScriptRoot 'build.py') --version $Version
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Review the output above.' }
