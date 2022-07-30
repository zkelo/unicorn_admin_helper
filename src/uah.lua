--[[ Зависимости ]]
local encoding = require 'encoding'
local samp = require 'samp.events'

--[[ Метаданные ]]
script_name(_('Unicorn Admin Helper'))
script_author(_('ZKelo'))
script_description(_('Скрипт в помощь администратору игрового сервера Unicorn'))
script_version(_('2.0.5'))
script_version_number(5)
script_moonloader(26)
script_dependencies('samp')

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
