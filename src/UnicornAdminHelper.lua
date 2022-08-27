--[[ Зависимости ]]
local inicfg = require 'inicfg'
local samp = require 'samp.events'
local vkeys = require 'vkeys'
local winmsg = require 'windows.message'

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
    settings = {
        id = 100,
        hotkey = 101,
        maxListitem = 0
    },
    commands = {
        id = 103
    },
    suspects = {
        list = 102
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

local keyCapture = {
    id = nil,
    setting = nil,
    fnc = nil
}

local suspectsListShownCounter = 0
local suspectsListItemIndex = nil
local backwardToSettingsFromCurrentDialog = false
local serverSuspects = {}

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

function showHotkeyCaptureDialog()
    local content = string.format(
        '%sВы меняете клавишу для функции:\n%s%s%s\n\nТекущая клавиша: %s%s\n\n%sНажмите любую клавишу чтобы сохранить её\nв качестве горячей клавиши для указанной функции',
        c(color.white), c(color.grey), keyCapture.fnc, c(color.white),
        c(color.yellow), vkeys.id_to_name(keyCapture.id), c(color.green)
    )

    sampShowDialog(dialog.settings.hotkey, c(color.system) .. 'Назначение клавиши', content, 'Выбрать', 'Назад')
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
            -- 0                      1                        2
            '%s--- Wallhack в слежке\nКлавиша активации: %s%s\n \n',
            c(color.yellow), c(color.grey), vkeys.id_to_name(data.settings.hotkeyWallhack)
        ) .. string.format(
            -- 3                       4                              5                             6                       7
            '%s--- Список нарушителей\nКлавиша открытия списка: %s%s\nКлавиша редактирования: %s%s\nКлавиша удаления: %s%s\n \n',
            c(color.yellow), c(color.grey), vkeys.id_to_name(data.settings.hotkeySuspectsList),
            c(color.grey), vkeys.id_to_name(data.settings.hotkeySuspectsEdit),
            c(color.grey), vkeys.id_to_name(data.settings.hotkeySuspectsDelete)
        ) .. string.format(
            -- 8            9
            '%s--- Команды\nНастройка команд',
            c(color.yellow)
        )
        _, dialog.settings.maxListitem = content:gsub('\n', '')

        sampShowDialog(dialog.settings.id, c(color.system) .. 'Управление скриптом ' .. thisScript().name .. ' ' .. thisScript().version, content, 'Выбрать', 'Закрыть', DIALOG_STYLE_LIST)
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

        if suspectsListShownCounter >= 31 or suspectsListShownCounter == 0 then
            sampAddChatMessage(string.format('Подсказка: %sС помощью клавиши %s%s%s можно удалить игрока из списка нарушителей', c(color.white), c(color.yellow), vkeys.id_to_name(vkeys.VK_DELETE), c(color.white)), color.green)
            sampAddChatMessage(string.format('Подсказка: %sС помощью клавиши %s%s%s можно изменить комментарий', c(color.white), c(color.yellow), vkeys.id_to_name(vkeys.VK_SPACE), c(color.white)), color.green)

            suspectsListShownCounter = 1
        end

        suspectsListShownCounter = suspectsListShownCounter + 1
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

        if suspectsListItemIndex ~= nil then
            sampProcessChatInput('/suspects')
            sampSetCurrentDialogListItem(suspectsListItemIndex)

            suspectsListItemIndex = nil
        end
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

        --[[ Обработка нажатий клавиш ]]
        if not sampIsChatInputActive()
            and not sampIsDialogActive()
            and isKeyJustPressed(data.settings.hotkeySuspectsList)
        then
            sampProcessChatInput('/suspects')
        end

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

        -- Диалог с настройками
        result, button, listitem = sampHasDialogRespond(dialog.settings.id)
        if result and button == 1 then
            if listitem == 1
                or listitem == 4
                or listitem == 5
                or listitem == 6
            then
                if listitem == 1 then
                    keyCapture.fnc = 'Активация Wallhack в слежке'
                    keyCapture.id = data.settings.hotkeyWallhack
                    keyCapture.setting = 'hotkeyWallhack'
                elseif listitem == 4 then
                    keyCapture.fnc = 'Открытие списка нарушителей'
                    keyCapture.id = data.settings.hotkeySuspectsList
                    keyCapture.setting = 'hotkeySuspectsList'
                elseif listitem == 5 then
                    keyCapture.fnc = 'Редактирование записи в списке нарушителей'
                    keyCapture.id = data.settings.hotkeySuspectsEdit
                    keyCapture.setting = 'hotkeySuspectsEdit'
                elseif listitem == 6 then
                    keyCapture.fnc = 'Удаление из списка нарушителей'
                    keyCapture.id = data.settings.hotkeySuspectsDelete
                    keyCapture.setting = 'hotkeySuspectsDelete'
                end

                backwardToSettingsFromCurrentDialog = true
                showHotkeyCaptureDialog()
            elseif listitem == 0
                or listitem == 2
                or listitem == 3
                or listitem == 7
                or listitem == 8
            then
                sampProcessChatInput('/uah')
            elseif listitem == 9 then
                local content = ''

                sampShowDialog(dialog.commands.id, 'Настройка команд', content, 'Выбрать', 'Назад', DIALOG_STYLE_TABLIST_HEADERS)
            end
        end

        -- Диалог назначения клавиши
        result, button, listitem = sampHasDialogRespond(dialog.settings.hotkey)
        if result then
            if button == 1 then
                data.settings[keyCapture.setting] = keyCapture.id
                saveData()
            end

            if backwardToSettingsFromCurrentDialog then
                backwardToSettingsFromCurrentDialog = false
                sampProcessChatInput('/uah')
            end
        end

        -- Действия при открытых диалогах
        if sampIsDialogActive() and sampIsDialogClientside() then
            -- Диалог со списком нарушителей
            if sampGetCurrentDialogId() == dialog.suspects.list then
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
                        suspectsListItemIndex = sampGetCurrentDialogListItem()
                    end
                end
            end
        end
    end
end

--[[ Обработка нажатий клавиш ]]
function onWindowMessage(msg, wparam, lparam)
    if msg == winmsg.WM_KEYDOWN
        and sampIsDialogActive()
        and sampIsDialogClientside()
        and sampGetCurrentDialogId() == dialog.settings.hotkey
    then
        -- Запись нажатой клавиши при назначении клавиши
        keyCapture.id = wparam
        showHotkeyCaptureDialog()
    end
end

--[[ Обработка входящих сообщений от сервера ]]
function samp.onServerMessage(_, text)
    -- Серверное сообщение о подозрении в читерстве
    if text:find('/подозревается%sв%sчитерстве/') ~= nil then
        local openBracket = text:find('[', 20)
        local closeBracket = text:find(']', 20)

        local suspectId = text:sub(openBracket + 1, closeBracket - 1)
        sampAddChatMessage(string.format('Обнаружен читер - ID: %d', suspectId), color.system)
    end
end
