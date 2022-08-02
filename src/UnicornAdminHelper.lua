--[[ Зависимости ]]
local inicfg = require 'inicfg'
local samp = require 'samp.events'
local k = require 'vkeys'

--[[ Метаданные ]]
script_name('Unicorn Admin Helper')
script_author('ZKelo')
script_description('Скрипт в помощь администратору игрового сервера Unicorn')
script_version('2.0.5')
script_version_number(5)
script_moonloader(26)
script_dependencies('encoding', 'samp')

--[[ Переменные и значения по умолчанию ]]
local configFilename = 'UnicornAdminHelper'

local color = {
    white = 0xFFFFFF,
    red = 0xF07474,
    green = 0x86E153,
    yellow = 0xF3D176,
    grey = 0xC6C6C6,
    lightGrey = 0xE5E5E5,

    system = 0xAACCFF
}

local dialog = {
    suspects = {
        list = 100
    }
}

local suspects = {}
local isPlayerSpectating = false

local data = inicfg.load({
    settings = {
        autoPageSize = 0
    },
    suspects = {}
}, configFilename)

if data.suspects == nil then
    data.suspects = {}
end

--[[ Вспомогательные функции ]]
function saveData()
    if not inicfg.save(data, configFilename) then
        print('Не удалось сохранить данные в файл')
    end
end

function addSuspect(name, comment)
    data.suspects[name] = comment
    saveData()
end

function delSuspect(name)
    data.suspects[name] = nil
    saveData()
end

function c(color)
    return '{' .. string.format('%x', color) .. '}'
end

function isEmpty(var)
    return var == nil or #var == 0
end

function isPlayerWithNicknameOnline(nickname)
    return not (getPlayerIdByNickname(nickname) == nil)
end

function getPlayerIdByNickname(nickname)
    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) and sampGetPlayerNickname(id) == nickname then
            return id
        end
    end

    return nil
end

function getSuspectNicknameByIndex(index)
    local i = 0

    for nickname, _ in pairs(data.suspects) do
        if i == index then
            return nickname
        end

        i = i + 1
    end

    return nil
end

--[[ Главные функции ]]
function main()
    -- Если SAMP или SAMPFUNCS не загружен,
    -- то скрипт не будет работать
    if not isSampLoaded() or not isSampfuncsLoaded() then
        return
    end

    -- Ожидание до тех пор, пока фукнции SAMP не станут доступны
    while not isSampAvailable() do
        wait(100)
    end

    -- Приветственное сообщение
    sampAddChatMessage(thisScript().name .. ' ' .. thisScript().version .. ' успешно загружен', color.system)
    sampAddChatMessage('Для просмотра справки введите /uah', color.yellow)

    -- Регистрация команд чата
    sampRegisterChatCommand('suspects', function ()
        local text = 'Статус\tНикнейм\tКомментарий'

        local list = ''
        for nickname, comment in pairs(data.suspects) do
            if comment == '(не указан)' then
                comment = c(color.lightGrey) .. comment
            end

            list = list .. '\n' .. (isPlayerWithNicknameOnline(nickname) and c(color.green) .. 'Онлайн' or c(color.red) .. 'Оффлайн') .. '\t' .. nickname .. '\t' .. comment
        end

        if isEmpty(list) then
            list = '\nСписок пуст\t\t'
        end

        sampShowDialog(dialog.suspects.list, 'Список нарушителей', text .. list, 'Следить', 'Закрыть', DIALOG_STYLE_TABLIST_HEADERS)
    end)

    sampRegisterChatCommand('su', function (args)
        local hint = 'Подсказка: ' .. c(color.white) ..'/su ' .. c(color.lightGrey) .. '[никнейм] [Комментарий (необязательно)] ' .. c(color.grey) .. '(добавить игрока в список нарушителей)'

        if isEmpty(args) then
            sampAddChatMessage(hint, color.green)
            return
        end

        nickname, comment = args:match('([^%s ]+)%s*(.*)')

        if isEmpty(nickname) then
            sampAddChatMessage(hint, color.green)
            return
        end

        if not isEmpty(data.suspects[nickname]) then
            delSuspect(nickname)
        end

        local msg = string.format('Игрок %q добавлен в список нарушителей', nickname)

        if not isEmpty(comment) then
            addSuspect(nickname, comment)
            sampAddChatMessage(msg, color.grey)
            return
        end

        comment = '(не указан)'
        addSuspect(nickname, comment)
        sampAddChatMessage(msg, color.grey)
    end)

    sampRegisterChatCommand('delsu', function (arg)
        nickname = arg:match('([^%s ]+)')

        if isEmpty(nickname) then
            sampAddChatMessage('Подсказка: ' .. c(color.white) .. '/delsu ' .. c(color.lightGrey) .. '[никнейм] ' .. c(color.grey) .. '(удалить игрока из списка нарушителей)', color.green)
            return
        end

        delSuspect(nickname)
        sampAddChatMessage(string.format('Игрок %q удалён из списка нарушителей', nickname), color.grey)
    end)

    -- Регистрация консольных команд
    sampfuncsRegisterConsoleCommand('uah', function (arg)
        if isEmpty(arg) then
            print('uah [[num_]version | suspects]')
        elseif arg == 'version' then
            print(thisScript().name .. ' ' .. thisScript().version)
        elseif arg == 'num_version' then
            print(tostring(thisScript().version_num))
        elseif arg == 'suspects' then
            for name, comment in pairs(data.suspects) do
                print(string.format('%q: %q', name, comment))
            end
        end
    end)

    -- Главный цикл
    while true do
        wait(0)

        --[[ Обработка диалогов ]]
        -- Диалог со списком нарушителей
        local result, button, listitem = sampHasDialogRespond(dialog.suspects.list)
        if result and button == 1 then
            local nickname = getSuspectNicknameByIndex(listitem)

            if not nickname == nil then
                local playerId = getPlayerIdByNickname(nickname)

                if isPlayerWithNicknameOnline(nickname) then
                    sampSendChat(string.format('/re %i', playerId))
                else
                    sampAddChatMessage(string.format('Игрок %q сейчас оффлайн', nickname), color.red)
                end
            end
        end

        --[[ Обработка нажатий клавиш ]]
        -- Открытие списка нарушителей (F2)
        if isKeyJustPressed(k.VK_F2) then
            sampProcessChatInput('/suspects')
        elseif isKeyJustPressed(k.VK_DELETE) and sampIsDialogActive() and sampGetCurrentDialogId(dialog.suspects.list) then
            local listitem = sampGetCurrentDialogListItem()
            local nickname = getSuspectNicknameByIndex(listitem)

            sampProcessChatInput(string.format('/delsu %s', nickname))
            sampProcessChatInput('/suspects')
        end
    end
end

--[[ Обработчики событий ]]
function samp.onSendCommand(command)
    -- Здесь должен быть обработчик команд
    -- с возможностью добавления собственных
end
function samp.onTogglePlayerSpectating(state)
    isPlayerSpectating = state
end
