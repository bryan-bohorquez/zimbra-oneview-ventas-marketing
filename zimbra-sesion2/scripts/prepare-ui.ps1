$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source = Join-Path $projectRoot 'compiled-ui\browser'
$target = Join-Path $projectRoot 'backend\src\main\resources\static'
$expectedTarget = [IO.Path]::GetFullPath((Join-Path $projectRoot 'backend\src\main\resources\static'))

if (-not (Test-Path -LiteralPath $source)) {
    throw 'No se encontro el frontend compilado. Ejecuta npm run build primero.'
}
if ([IO.Path]::GetFullPath($target) -ne $expectedTarget) {
    throw 'La carpeta destino no coincide con los recursos estaticos del backend.'
}
New-Item -ItemType Directory -Force -Path $target | Out-Null
Get-ChildItem -LiteralPath $target -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
Write-Host 'Interfaz Angular copiada al backend. Al iniciar Java, abrira desde el mismo origen que la API.'
