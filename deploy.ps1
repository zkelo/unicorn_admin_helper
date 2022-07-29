. .\scripts\vars.ps1

<# Перменные #>
$DistFolder = 'dist'

$ScriptFilename = Split-Path $ScriptPath -leaf
$CompiledScriptFilename = "$($ScriptFilename)c"

$CompiledScriptPath = ".\$DistFolder\$CompiledScriptFilename"
$CompiledScriptGameFolderPath = "$GamePath\moonloader\$CompiledScriptFilename"

<# Код #>
if (Test-Path -Path $CompiledScriptPath -PathType leaf)
{
    Remove-Item -Force $CompiledScriptPath
}

cd .\luajit
& '.\luajit.exe' '-b' ".$ScriptPath" ".$CompiledScriptPath"
cd ..

Try
{
    '' | Out-File $CompiledScriptGameFolderPath
}
Catch
{
    Write-Error 'Нет прав на запись в папку игры'
}

Remove-Item -Force $CompiledScriptGameFolderPath
Copy-Item -Force -Path $CompiledScriptPath -Destination $CompiledScriptGameFolderPath
