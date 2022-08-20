--[[ Зависимости ]]
local inicfg = require 'inicfg'
local samp = require 'samp.events'
local vkeys = require 'vkeys'

--[[ Метаданные ]]
script_name('Unicorn Admin Helper')
script_author('ZKelo')
script_description('Скрипт в помощь администратору игрового сервера Unicorn')
script_version('2.0.0')
script_version_number(5)
script_moonloader(26)
script_dependencies('encoding', 'samp')

--[[ Переменные и значения по умолчанию ]]
local configFilename = 'UnicornAdminHelper'

local color = {
    white = 0xffffff,
    red = 0xf07474,
    green = 0x86e153,
    yellow = 0xf3d176,
    grey = 0xc6c6c6,
    lightGrey = 0xe5e5e5,
    darkGrey = 0x444444,

    system = 0xaaccff
}

local dialog = {
    main = 100,
    suspects = {
        list = 101
    }
}

local suspects = {}

local data = inicfg.load({
    settings = {
        autoPageSize = 0,
        hotkeyWallhack = vkeys.VK_F3,
        hotkeySuspectsList = vkeys.VK_F2,
        hotkeySuspectsDelete = vkeys.VK_DELETE,
        hotkeySuspectsEdit = vkeys.VK_SPACE
    },
    suspects = {},
    commands = {}
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
    return getPlayerIdByNickname(nickname) ~= nil
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
    sampRegisterChatCommand('uah', function ()
        local content = string.format(
            '%s--- Wallhack в слежке\nКлавиша активации: %s%s\n \n',
            c(color.yellow), c(color.grey), vkeys.id_to_name(data.settings.hotkeyWallhack)
        ) .. string.format(
            '%s--- Список нарушителей\nКлавиша открытия списка: %s%s\nКлавиша редактирования: %s%s\nКлавиша удаления: %s%s\n \n',
            c(color.yellow), c(color.grey), vkeys.id_to_name(data.settings.hotkeySuspectsList),
            c(color.grey), vkeys.id_to_name(data.settings.hotkeySuspectsEdit),
            c(color.grey), vkeys.id_to_name(data.settings.hotkeySuspectsDelete)
        ) .. string.format(
            '%s--- Команды\n%sДобавить команду\n/mq %s- выдача мута за упом. родных\n/mm %s- выдача мута за мат',
            c(color.yellow), c(color.green), c(color.grey), c(color.grey)
        )

        sampShowDialog(dialog.main, c(color.system) .. 'Управление скриптом ' .. thisScript().name .. ' ' .. thisScript().version, content, 'Выбрать', 'Закрыть', DIALOG_STYLE_LIST)
    end)

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

        sampAddChatMessage(string.format('Подсказка: %sС помощью клавиши %s%s%s можно удалить игрока из списка нарушителей', c(color.white), c(color.yellow), vkeys.id_to_name(vkeys.VK_DELETE), c(color.white)), color.green)
        sampAddChatMessage(string.format('Подсказка: %sС помощью клавиши %s%s%s можно изменить комментарий', c(color.white), c(color.yellow), vkeys.id_to_name(vkeys.VK_SPACE), c(color.white)), color.green)

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

        local lowerNickname = nickname:lower()

        local _, localPlayerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local localPlayerName = sampGetPlayerNickname(localPlayerId)
        if lowerNickname == localPlayerName:lower() then
            sampAddChatMessage('Вы не можете добавить себя в список нарушителей', color.red)
            return
        end

        if not isEmpty(data.suspects[lowerNickname]) then
            delSuspect(nickname)
        end

        if isEmpty(comment) then
            comment = '(не указан)'
        end

        addSuspect(nickname, comment)
        sampAddChatMessage(string.format('Игрок %q добавлен в список нарушителей', nickname), color.grey)
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

            if nickname ~= nil then
                if isPlayerWithNicknameOnline(nickname) then
                    sampSendChat(string.format('/re %d', getPlayerIdByNickname(nickname)))
                else
                    sampAddChatMessage(string.format('Игрок %q сейчас оффлайн', nickname), color.red)
                end
            end
        end

        --[[ Обработка нажатий клавиш ]]
        -- Открытие списка нарушителей (F2)
        if isKeyJustPressed(data.settings.hotkeySuspectsList) then
            sampProcessChatInput('/suspects')
        end

        -- Действия при открытых диалогах
        if sampIsDialogActive() and sampIsDialogClientside() then
            -- Диалог со списком нарушителей
            if sampGetCurrentDialogId(dialog.suspects.list) then
                local listitem = sampGetCurrentDialogListItem()
                local nickname = getSuspectNicknameByIndex(listitem)

                if nickname ~= nil then
                    if isKeyJustPressed(data.settings.hotkeySuspectsDelete) then
                        -- Удаление из списка
                        delSuspect(nickname)
                        sampProcessChatInput('/suspects')
                    elseif isKeyJustPressed(data.settings.hotkeySuspectsEdit) then
                        -- Изменение комментария
                        sampCloseCurrentDialogWithButton(0)
                        sampProcessChatInput('/su')
                        sampSetChatInputEnabled(true)
                        sampSetChatInputText(string.format('/su %s %s', nickname, data.suspects[nickname]))
                    end
                end
            end
        end
    end
end
