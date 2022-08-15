. .\scripts\vars.ps1

<# Перменные #>
$DistFolder = 'dist'

$ScriptFilename = Split-Path $ScriptPath -leaf
$CompiledScriptFilename = "$($ScriptFilename)c"

$CompiledScriptPath = ".\$DistFolder\$CompiledScriptFilename"
$CompiledScriptGameFolderPath = "$GamePath\moonloader\$CompiledScriptFilename"

<# Код #>
Get-Content -Encoding UTF8 $ScriptPath | Out-File -Encoding WINDOWS-1251 "$DistFolder\$ScriptFilename"

Write-Output 'Компиляция скрипта...'

if (Test-Path -Path $CompiledScriptPath -PathType leaf)
{
    Remove-Item -Force $CompiledScriptPath
}

cd .\luajit
& '.\luajit.exe' '-b' "..\$DistFolder\$ScriptFilename" ".$CompiledScriptPath"
cd ..

if (-not (Test-Path -Path $CompiledScriptPath -PathType leaf))
{
    Write-Error -Message 'Не удалось скомпилировать скрипт' -RecommendedAction 'Проверьте код на ошибки и запустите комиляцию снова' -Category SyntaxError
    Exit 1
}
else
{
    Write-Host 'Скрипт успешно скомпилирован' -ForegroundColor Green
}

Remove-Item -Force "$DistFolder\$ScriptFilename"
Write-Output 'Копирование скрипта в папку moonloader игры...'

Try
{
    '' | Out-File $CompiledScriptGameFolderPath
}
Catch
{
    Write-Error 'Нет прав на запись в папку игры' -RecommendedAction 'Попробуйте запустить скрипт компиляции с правами администратора' -Category PermissionDenied
}

Remove-Item -Force $CompiledScriptGameFolderPath
Copy-Item -Force -Path $CompiledScriptPath -Destination $CompiledScriptGameFolderPath

if (Test-Path -Path $CompiledScriptGameFolderPath -PathType leaf)
{
    Write-Host 'Скрипт успешно скопирован' -ForegroundColor Green
}
