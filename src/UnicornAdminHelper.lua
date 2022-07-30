--[[ Зависимости ]]
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local samp = require 'samp.events'

--[[ Переменные и значения по умолчанию ]]
encoding.default = 'utf-8'

local configFilename = 'UnicornAdminHelper'

local suspects = {}

local data = inicfg.load({
    settings = {
        debug = false
    },
    suspects = {}
}, configFilename)

--[[ Вспомогательные функции ]]
function _(text)
    return encoding.cp1251:encode(text)
end

function saveData()
    if not inicfg.save(data, configFilename) and data.settings.debug then
        print('Не удалось сохранить данные в файл')
    end
end

function addSuspect(name, comment)
    data.suspects[name] = comment
    saveData()
end

function delSuspect(name)
    data.suspects:remove(name)
    saveData()
end

--[[ Метаданные ]]
script_name(_('Unicorn Admin Helper'))
script_author(_('ZKelo'))
script_description(_('Скрипт в помощь администратору игрового сервера Unicorn'))
script_version(_('2.0.5'))
script_version_number(5)
script_moonloader(26)
script_dependencies('encoding', 'samp')

--[[ Главные функции ]]
function main()
    -- Если SAMP или SAMPFUNCS не загружен,
    -- то скрипт не будет работать
    if not isSampLoaded() or not isSampfuncsLoaded() then
        return
    end

    -- Ожидание до тех пор, пока SAMP не станет доступен
    while not isSampAvailable() do
        wait(100)
    end

    -- Регистрация команд чата
    --[[ TODO ]]

    -- Регистрация консольных команд
    sampfuncsRegisterConsoleCommand('uah', function (arg)
        if #arg == 0 then
            print('uah [[num_]version | debug]')
        elseif arg == 'version' then
            print(thisScript().name .. ' ' .. thisScript().version)
        elseif arg == 'num_version' then
            print(tostring(thisScript().version_num))
        elseif arg == 'debug' then
            data.settings.debug = not data.settings.debug
            print(data.settings.debug and _('Отладка включена') or _('Отладка выключена'))
            saveData()
        end
    end)

    wait(-1)
end

--[[ Обработчики событий ]]
function samp.onSendCommand(command)
    -- Здесь должен быть обработчик команд
    -- с возможность добавления собственных
end
