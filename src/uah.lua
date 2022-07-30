--[[ Зависимости ]]
local encoding = require 'encoding'
local samp = require 'samp.events'

--[[ Переменные и значения по умолчанию ]]
encoding.default = 'utf-8'

local players = {}

--[[ Вспомогательные функции ]]
function _(text)
    return encoding.cp1251:encode(text)
end

--[[ Метаданные ]]
script_name(_('Unicorn Admin Helper'))
script_author(_('ZKelo'))
script_description(_('Скрипт в помощь администратору игрового сервера Unicorn'))
script_version(_('2.0.5'))
script_version_number(5)
script_moonloader(26)
script_dependencies('samp')

--[[ Главные функции ]]
function main()
    -- Регистрация команд чата
    -- [[ TODO ]]

    -- Регистрация консольных команд
    sampfuncsRegisterConsoleCommand('uah', function (args)
        if #args == 0 then
            print('uah [version|debug]')
        else
            print(args)
        end
    end)

    wait(-1)
end

--[[ Обработчики событий ]]
function samp.onPlayerJoin(playerId, color, isNpc, nickname)
    players:insert(playerId + 1, nickname)
end

function samp.onPlayerQuit(playerId)
    players:remove(playerId + 1)
end

function samp.onSendCommand(command)
    -- Здесь должен быть обработчик команд
    -- с возможность добавления собственных
end
