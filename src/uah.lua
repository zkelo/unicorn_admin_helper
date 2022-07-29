local encoding = require 'encoding'

encoding.default = 'utf-8'

function main()
    sampAddChatMessage(_'Тест utf8', -1)
end

function _(text)
    return encoding.cp1251:encode(text)
end
