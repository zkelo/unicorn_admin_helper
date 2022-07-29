. .\scripts\vars.ps1

<# Перменные #>
# Путь к временной папке
$DistFolder = 'tmp'

# Название файла со скриптом из $ScriptPath
$ScriptFilename = Split-Path $ScriptPath -leaf

# Полный путь к скомилированному скрипту во временной папке
$CompiledScriptPath = "..\$DistFolder\$($ScriptFilename)c"

<# Код #>
New-Item -ItemType 'directory' -Name $DistFolder -Path './'

cd .\luajit
& '.\luajit.exe' '-b' ".$ScriptPath" $CompiledScriptPath
cd ..
