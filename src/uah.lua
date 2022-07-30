--[[ Зависимости ]]
local encoding = require 'encoding'
local samp = require 'samp.events'

--[[ Переменные и значения по умолчанию ]]
encoding.default = 'utf-8'

local debug = false
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
    -- [[ TODO ]] --

    -- Регистрация консольных команд
    if isSampfuncsLoaded() then
        sampfuncsRegisterConsoleCommand('uah', function (arg)
            if #arg == 0 then
                print('uah [[num_]version | debug]')
            elseif arg == 'version' then
                print(thisScript().name .. ' ' .. thisScript().version)
            elseif arg == 'debug' then
                debug = not debug
                print(debug and _('Отладка включена') or _('Отладка выключена'))
            end
        end)
    end

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
