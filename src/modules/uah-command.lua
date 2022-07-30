--[[ Модуль обработки команд ]]

local defined_commands = {}
local command = {}

command.handle = function (command)
    sampAddChatMessage(_('Команда' .. command), -1)
end
