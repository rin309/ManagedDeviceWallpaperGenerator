Get-ChildItem -Path (Join-Path $PSScriptRoot "Scripts\*.ps1") | ForEach-Object { . $_}
