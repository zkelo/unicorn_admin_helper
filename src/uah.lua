--[[ Глобальные модули ]]
local encoding = require 'encoding'
local samp = require 'samp\\events'

--[[ Модули скрипта ]]
local command = require 'modules\\uah-command'

--[[ Переменные и значения по умолчанию ]]
encoding.default = 'utf-8'

--[[ Главные функции ]]
function main()
    wait(-1)
end

--[[ Обработчики событий ]]
function samp.onSendCommand(command)
    return command:handle(command)
end

--[[ Вспомогательные функции ]]
function _(text)
    return encoding.cp1251:encode(text)
end
