. .\scripts\vars.ps1

<# Перменные #>
# Путь к временной папке
$DistFolder = 'dist'

# Название файла со скриптом из $ScriptPath
$ScriptFilename = Split-Path $ScriptPath -leaf

# Полный путь к скомилированному скрипту во временной папке
$CompiledScriptPath = "..\$DistFolder\$($ScriptFilename)c"

if (Test-Path -Path $CompiledScriptPath -PathType leaf)
{
    Remove-Item -Force $CompiledScriptPath
}

<# Код #>
New-Item -ItemType 'directory' -Name $DistFolder -Path './'

cd .\luajit
& '.\luajit.exe' '-b' ".$ScriptPath" $CompiledScriptPath
cd ..
