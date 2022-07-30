--[[ Зависимости ]]
local encoding = require 'encoding'
local samp = require 'samp.events'

--[[ Переменные и значения по умолчанию ]]
encoding.default = 'utf-8'

--[[ Главные функции ]]
function main()
    wait(-1)
end

--[[ Обработчики событий ]]
function samp.onSendCommand(command)
    -- Здесь должен быть обработчик команд
    -- с возможность добавления собственных
end

--[[ Вспомогательные функции ]]
function _(text)
    return encoding.cp1251:encode(text)
end
