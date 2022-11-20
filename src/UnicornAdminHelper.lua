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
-- Название конфигурационного файла
local configFilename = 'UnicornAdminHelper'

-- Цвета
local color = {
    white = 0xffffff,
    red = 0xf07474,
    brightRed = 0xff0000,
    green = 0x86e153,
    yellow = 0xf3d176,
    grey = 0xc6c6c6,
    lightGrey = 0xe5e5e5,
    darkGrey = 0x444444,
    system = 0xaaccff
}

-- Идентификаторы диалогов
local dialog = {
    settings = {
        id = 100,
        hotkey = 101,
        maxListitem = 0
    },
    suspects = {
        list = 102
    }
}

-- Данные (состояние) скрипта
local data = inicfg.load({
    -- Настройки
    settings = {
        -- Автоматический pagesize
        autoPageSize = 0,
        -- Клавиша включения\отключения Wallhack-а
        hotkeyWallhack = vkeys.VK_F3,
        -- Клавиша открытия списка нарушителей
        hotkeySuspectsList = vkeys.VK_F2,
        -- Клавиша удаления записи из списка нарушителей
        hotkeySuspectsDelete = vkeys.VK_DELETE,
        -- Клавиша редактирования записи в списке нарушителей
        hotkeySuspectsEdit = vkeys.VK_SPACE
    },
    -- Список нарушителей
    suspects = {},
    -- Команды
    commands = {
        --[[
            'a' = {
                text = 'a',
                args = {
                    'p' = 'ID игрока',
                    's' = 'Ответ'
                },
                info = 'ответить на репорт'
            }
         ]]
        '/a {d:ID игрока} {t:Ответ} - ответить на репорт>am:$1,$2',
        '/z {d:ID игрока} - следить за игроком>re:$1',
        '/so - выйти из слежки>exit',
        '/m {d:ID игрока} {d:Время} {t:Причина} - выдать бан чата>mute:$1,$2,$3',
        '/mx {s:Никнейм игрока} {d:Время} {t:Причина} - выдать бан чата>muteex:$1,$2,$3',
        '/mo {d:ID игрока} - выдать бан чата за оскорбление>mo:$1',
        '/mm {d:ID игрока} - выдать бан чата за мат>mm:$1',
        '/mf {d:ID игрока} - выдать бан чата за флуд>flame:$1',
        '/ms {d:ID игрока} - выдать бан чата за спам>ms:$1',
        '/mq {d:ID игрока} - выдать бан чата за упом. родных>mq:$1',
        '/sm {d:ID игрока} {d:Время} - изменить время бана чата>setmute:$1,$2',
        '/k {d:ID игрока} {t:Причина} - кикнуть>kick:$1,$2',
        '/j {d:ID игрока} {d:Время} {t:Причина} - посадить в тюрьму>jail:$1,$2,$3',
        '/w {d:ID игрока} {t:Причина} - выдать предупреждение>warn:$1,$2',
        '/bl {s:Никнейм игрока} - заблокировать аккаунт>block:$1',
        '/b {d:ID игрока} {t:Причина} - забанить игрока>ban:$1,$2,$3',
        '/bx {s:Никнейм игрока} {t:Причина} - забанить игрока>banex:$1,$2',
        '/bc {d:ID игрока} - забанить игрока за чит>ban:30+Cheat',
        '/um {d:ID игрока} - снять бан чата>unmute:$1',
        '/umx {s:Никнейм игрока} - снять бан чата>unmuteex:$1',
        '/uw {d:ID игрока} - снять предупреждение>unwarn:$1',
        '/uj {d:ID игрока} - выпустить из тюрьмы>unjail:$1',
        '/ub {s:Никнейм игрока} - разбанить>unban:$1',
        '/ubl {s:Никнейм игрока} - разблокировать аккаунт>unblock:$1'
    }
}, configFilename)
if data.suspects == nil then
    data.suspects = {}
end

-- Параметры команд
local cmdParams = {
    d = '(%d+)',
    s = '([^%s]+)',
    t = '(.+)'
}

-- Переменная-состояние для диалога назначения горячей клавиши
local keyCapture = {
    id = nil,
    setting = nil,
    fnc = nil
}

-- Количество открытий списка нарушителей пользователем скрипта
-- Используется для того чтобы не выводить подсказку по горячим клавишам
-- редактирования и удаления записей в списке нарушителей каждый раз
-- при его открытии, тем самым не флудить подсказкой,
-- если пользователь часто открывает список
local suspectsListShownCounter = 0

local suspectsListItemIndex = nil
local backwardToSettingsFromCurrentDialog = false
local serverSuspects = {}

--[[ Вспомогательные функции ]]
-- Сохранение данных (состояния) скрипта
function saveData()
    local d = data
    local cl = {}
    for k, c in pairs(d.commands) do
        cl[k] = c.raw
    end
    d.commands = cl

    if not inicfg.save(d, configFilename) then
        print('Не удалось сохранить данные в файл')
    end
end

-- Подготовка никнейма игрока, добавляемого в список нарушителей
function prepareSuspectName(name, toSave)
    if toSave then
        return name:gsub('%.', '~')
    end

    return name:gsub('~', '%.')
end

-- Добавление игрока в список нарушителей
function addSuspect(name, comment)
    name = prepareSuspectName(name, true)
    data.suspects[name] = comment
    saveData()
end

-- Удаление игрока из списка нарушителей
function delSuspect(name)
    name = prepareSuspectName(name, true)
    data.suspects[name] = nil
    saveData()
end

-- Вспомогательная функция для вставки цвета в сообщение
function c(color)
    return '{' .. string.format('%x', color) .. '}'
end

-- Проверяет, является ли значение переданной переменной пустым
function isEmpty(var)
    return var == nil or #var == 0
end

-- Проверяет, находится ли игрок с определённым никнеймом в сети
function isPlayerWithNicknameOnline(nickname)
    return getPlayerIdByNickname(nickname) ~= nil
end

-- Получает ID игрока по его никнейму
-- Если игрок не в сети, возвращает `nil`
function getPlayerIdByNickname(nickname)
    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) and sampGetPlayerNickname(id) == nickname then
            return id
        end
    end

    return nil
end

-- Возвращает никнейм игрока из списка нарушителей
-- по индексу его записи в списке
-- Если игрок не в сети, возвращает `nil`
function getSuspectNicknameByIndex(index)
    local i = 0

    for nickname, _ in pairs(data.suspects) do
        nickname = prepareSuspectName(nickname, false)

        if i == index then
            return nickname
        end

        i = i + 1
    end

    return nil
end

-- Выводит на экран пользователя диалог назначения
-- горячей клавиши для какой-либо функции
function showHotkeyCaptureDialog()
    local content = string.format(
        '%sВы меняете клавишу для функции:\n%s%s%s\n\nТекущая клавиша: %s%s\n\n%sНажмите любую клавишу чтобы сохранить её\nв качестве горячей клавиши для указанной функции',
        c(color.white), c(color.grey), keyCapture.fnc, c(color.white),
        c(color.yellow), vkeys.id_to_name(keyCapture.id), c(color.green)
    )

    sampShowDialog(dialog.settings.hotkey, c(color.system) .. 'Назначение клавиши', content, 'Сохранить', 'Назад')
end

-- Обрабатывает список команд, собирая из него таблицу
function parseCommands(commands)
    local list = {}

    for _, c in ipairs(commands) do
        local l, r = c:match('([^%>]+)>(.+)')

        local m = ''
        for x, _ in pairs(cmdParams) do
            m = m .. x
        end

        --[[ Эту часть кода можно отрефакторить! ]]
        local t, a, i = l:match('%/(%w+)%s(%{[' .. m .. ']%:.+%})%s-%s(.+)')
        if t == nil then
            t, i = l:match('%/(%w+)%s-%s(.+)')
            a = nil
        end
        --[[ /Эту часть кода можно отрефакторить! ]]

        local g = {}
        if a ~= nil then
            for p, j in a:gmatch('%{([dst]+):([^%}]+)%}') do
                table.insert(g, {param = p, info = j})
            end
        end

        list[t] = {
            raw = c,
            text = t,
            args = g,
            info = i,
            result = r
        }
    end

    return list
end

-- Обрабатывает собственные команды
function handleCustomCommand(text, args)
    --[[ Проверка на существование команды ]]
    local cmd = data.commands[text]
    if cmd == nil then
        sampAddChatMessage(string.format('Ошибка: %sНе удалось найти команду', c(color.white)), color.red)
        return
    end

    --[[ Генерация подсказки ]]
    local hint = ''
    if not isEmpty(cmd.args) then
        local ps = ''
        for _, p in ipairs(cmd.args) do
            ps = string.format('%s[%s] ', ps, p.info)
        end

        hint = string.format(
            'Подсказка: %s/%s %s%s%s',
            c(color.white), text, ps, c(color.grey), cmd.info
        )

        if isEmpty(args) then
            sampAddChatMessage(hint, color.green)
            return
        end

        --[[ Обработка аргументов ]]
        local re, l = '', #cmd.args
        for i, p in ipairs(cmd.args) do
            re = string.format(
                '%s%s%%s' .. (i == l and '*' or '+'),
                re, cmdParams[p.param]
            )
        end

        args = {args:match(re)}
        if #args ~= #cmd.args then
            sampAddChatMessage(hint, color.green)
            return
        end
    end

    --[[ Сборка строки с результирующей командой ]]
    local result = '/' .. cmd.result:gsub('[,:]', ' ')

    if not isEmpty(args) then
        for i, p in ipairs(args) do
            result = result:gsub('$' .. i, p)
        end
    end

    --[[ Отправка ]]
    sampSendChat(result)
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

    --[[ Инициализация скрипта ]]
    -- Загрузка команд из конфига
    data.commands = parseCommands(data.commands)

    -- Приветственное сообщение
    sampAddChatMessage(thisScript().name .. ' ' .. thisScript().version .. ' успешно загружен', color.system)
    sampAddChatMessage('Для открытия настроек введите /uah', color.yellow)
    sampAddChatMessage(string.format(
        'В скрипт встроен Skeletal Wallhack%s от %sAppleThe%s и %shnnssy',
        c(color.grey), c(color.green), c(color.grey), c(color.green)
    ), color.grey)

    -- Регистрация основных команд чата
    sampRegisterChatCommand('uah', function ()
        local commands = ''

        for text, cmd in pairs(data.commands) do
            local ps = ''

            if not isEmpty(cmd.args) then
                for _, param in ipairs(cmd.args) do
                    ps = string.format('%s[%s] ', ps, param.info)
                end
            end

            commands = string.format(
                '%s%s/%s %s%s%s%s\n',
                commands, c(color.grey), text, c(color.lightGrey), ps, c(color.white), cmd.info
            )
        end

        if isEmpty(commands) then
            commands = 'Список команд пуст'
        end

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
            -- 8
            '%s--- Команды\n%s',
            c(color.yellow), commands
        )
        _, dialog.settings.maxListitem = content:gsub('\n', '')

        sampShowDialog(dialog.settings.id, c(color.system) .. 'Управление скриптом ' .. thisScript().name .. ' ' .. thisScript().version, content, 'Выбрать', 'Закрыть', DIALOG_STYLE_LIST)
    end)

    sampRegisterChatCommand('suspects', function ()
        local text = 'Статус\tНикнейм\tКомментарий'

        local list = ''
        for nickname, comment in pairs(data.suspects) do
            nickname = prepareSuspectName(nickname, false)

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

    -- Регистрация собственных команд
    for text, _ in pairs(data.commands) do
        sampRegisterChatCommand(text, function (args)
            handleCustomCommand(text, args)
        end)
    end

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
            then
                sampProcessChatInput('/uah')
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

        --[[ Действия при открытых диалогах ]]
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
function samp.onServerMessage(messageColor, text)
    messageColor = string.format('%x', messageColor):sub(-8, -3)

    -- Серверное сообщение о подозрении в читерстве
    if messageColor == 'f3333f' then
        local openBracket = text:find('[', 20)
        local closeBracket = text:find(']', 20)

        local suspectId = text:sub(openBracket + 1, closeBracket - 1)
        sampAddChatMessage(string.format('Обнаружен читер - ID: %d', suspectId), color.system)
    end
end
