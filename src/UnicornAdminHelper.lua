--[[ Зависимости ]]
local inicfg = require 'inicfg'
local samp = require 'samp.events'
local vkeys = require 'vkeys'
local winmsg = require 'windows.message'
local io = require 'io'
local ffi = require 'ffi'
local moonloader = require 'lib.moonloader'
local mem = require 'memory'

--[[ Метаданные ]]
script_name('Unicorn Admin Helper')
script_author('ZKelo')
script_description('Скрипт в помощь администратору игрового сервера Unicorn')
script_version('2.0.0')
script_version_number(5)
script_moonloader(26)
script_dependencies('encoding', 'samp')

--[[ Константы ]]
-- На самом деле, в Lua не существует констант,
-- поэтому здесь есть просто условность о том,
-- что если название переменной написано в верхнем регистре,
-- то переменная является константой и изменять её нельзя

-- Режимы Wallhack-а
local WALLHACK_MODE_ALL = 'all' -- Ники и скелет
local WALLHACK_MODE_BONES = 'bones' -- Только скелет
local WALLHACK_MODE_NAMES = 'names' -- Только ники

--[[ Переменные и значения по умолчанию ]]
-- Путь к папке config
local configDir = getWorkingDirectory() .. '/config'

-- Название конфигурационного файла
local configFilepath = configDir .. '/UnicornAdminHelper.json'

-- Отладка
local debug = false

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

-- Настройки скрипта по умолчанию
local defaults = {
    -- Автоматический pagesize
    autoPageSize = 0,
    -- Горячие клавиши
    hotkeys = {
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
        '/bc {d:ID игрока} - забанить игрока за чит>ban:$1+Cheat',
        '/um {d:ID игрока} - снять бан чата>unmute:$1',
        '/umx {s:Никнейм игрока} - снять бан чата>unmuteex:$1',
        '/uw {d:ID игрока} - снять предупреждение>unwarn:$1',
        '/uj {d:ID игрока} - выпустить из тюрьмы>unjail:$1',
        '/ub {s:Никнейм игрока} - разбанить>unban:$1',
        '/ubl {s:Никнейм игрока} - разблокировать аккаунт>unblock:$1'
    },
    -- Wallhack
    wallhack = {
        enabled = false,
        mode = WALLHACK_MODE_BONES
    }
}

-- Настройки скрипта
-- Они загружаются в функции `main()` до цикла
local settings

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

-- Индекс выбранного пункта в диалоге со списком нарушителей
local suspectsListItemIndex = nil

-- Флаг необходимости возврата в диалог настроек при закрытии открытого диалога
local backwardToSettingsFromCurrentDialog = false

-- Список нарушителей
local serverSuspects = {}

-- Поток для Wallhack-а
local wallhackThread

-- ID частей тела персонажа,
-- на которых будут отрисовываться
-- линии при включённом Wallhack-е
local wallhackBodyParts = {
    3, 4, 5, 51, 52,
    41, 42, 31, 32, 33,
    21, 22, 23, 2
}

-- Указатели на некоторые значения в памяти
local pointers = {
    nametags = {
        dist = 0,
        walls = 0,
        show = 0
    }
}

-- Настройки отображения ников по умолчанию
local nametagsDefaults = {
    dist = 0.0,
    walls = 0,
    show = 0
}

--[[ Вспомогательные функции ]]
-- Загрузка настроек скрипта
function loadSettings()
    local config = io.open(configFilepath, 'r')
    if config == nil then
        settings = defaults
        settings.commands = parseCommands(settings.commands)
        return
    end

    settings = decodeJson(config:read('*a'))
    config:close()

    --[[ Проверка корректности значений настроек ]]
    -- Список нарушителей должен быть таблицей
    if settings.suspects == nil then
        settings.suspects = {}
    end

    -- autoPageSize может иметь только следующие значения:
    -- 0 или от 10 до 20 включительно
    if settings.autoPageSize ~= 0 and (settings.autoPageSize < 10 or settings.autoPageSize > 20) then
        settings.autoPageSize = 0
    end

    -- Обработка команд
    if not pcall(function() settings.commands = parseCommands(settings.commands) end) then
        settings.commands = parseCommands(defaults.commands)
        print('Не удалось разобрать список команд. Восстановлены стандартные команды')
    end
end

-- Сохранение настроек скрипта
function saveSettings()
    local cl = {}
    for k, c in pairs(settings.commands) do
        cl[k] = c.raw
    end
    settings.commands = cl

    local config = io.open(configFilepath, 'w')
    config:write(encodeJson(settings))
    config:close()

    if not pcall(function () settings.commands = parseCommands(settings.commands) end) then
        settings.commands = parseCommands(defaults.commands)
        print('Не удалось разобрать список команд. Восстановлены стандартные команды')
    end
end

-- Добавление игрока в список нарушителей
function addSuspect(name, comment)
    settings.suspects[name] = comment
    saveSettings()
end

-- Удаление игрока из списка нарушителей
function delSuspect(name)
    settings.suspects[name] = nil
    saveSettings()
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

    for nickname, _ in pairs(settings.suspects) do
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

    for _, c in pairs(commands) do
        local l, r = c:match('([^%>]+)>(.+)')

        local m = ''
        for x, _ in pairs(cmdParams) do
            m = m .. x
        end

        local t, a, i = l:match('%/(%w+)%s(%{[' .. m .. ']%:.+%})%s-%s(.+)')
        if t == nil then
            t, i = l:match('%/(%w+)%s-%s(.+)')
            a = nil
        end

        local g = {}
        if a ~= nil then
            for p, j in a:gmatch('%{([' .. m .. ']+):([^%}]+)%}') do
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
    local cmd = settings.commands[text]
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

    --[[ Если включена отладка, то нужно просто вывести результат в чат ]]
    if debug then
        sampAddChatMessage(string.format(
            'Отладка: %sРезультат команды: %s%q',
            c(color.white), c(color.yellow), result
        ), color.yellow)
        return
    end

    --[[ Отправка ]]
    sampSendChat(result)
end

-- Возвращает координаты костей скелета персонажа
local getBonePosition = ffi.cast('int (__thiscall*)(void*, float*, int, bool)', 0x5e4280)

-- Переключает режим Wallhack-а (циклично)
function toggleWallhackMode()
    if settings.wallhack.mode == WALLHACK_MODE_ALL then
        settings.wallhack.mode = WALLHACK_MODE_BONES
    elseif settings.wallhack.mode == WALLHACK_MODE_BONES then
        settings.wallhack.mode = WALLHACK_MODE_NAMES
    elseif settings.wallhack.mode == WALLHACK_MODE_NAMES then
        settings.wallhack.mode = WALLHACK_MODE_ALL
    end

    if not settings.wallhack.enabled then
        return
    end

    if settings.wallhack.mode == WALLHACK_MODE_ALL or settings.wallhack.mode == WALLHACK_MODE_NAMES then
        wallhackToggleNametags(true)
    else
        wallhackToggleNametags(false)
    end
end

-- Возвращает название текущего режима Wallhack-а
function wallhackModeName()
    if settings.wallhack.mode == WALLHACK_MODE_NAMES then
        return 'Только ники'
    elseif settings.wallhack.mode == WALLHACK_MODE_BONES then
        return 'Только скелет'
    end

    return 'Ники и скелет'
end

-- Включает или выключает отображение ников при включённом Wallhack-е
function wallhackToggleNametags(toggle)
    if toggle then
        mem.setfloat(ntDistPtr, 1488.0)
        mem.setint8(ntWallsPtr, 0)
        mem.setint8(ntShowPtr, 1)
    else
        mem.setfloat(ntDistPtr, nametagsDefaults.dist)
        mem.setint8(ntWallsPtr, nametagsDefaults.walls)
        mem.setint8(ntShowPtr, nametagsDefaults.show)
    end
end

-- join_argb
function join_argb(a, r, g, b)
    local argb = b -- b
    argb = bit.bor(argb, bit.lshift(g, 8)) -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end

-- explode_argb
function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end

-- Возвращает координаты части тела персонажа
function getBodyPartCoordinates(id, handle)
    local ptr = getCharPointer(handle)
    local vec = ffi.new('float[3]')

    getBonePosition(ffi.cast('void*', ptr), vec, id, true)
    return vec[0], vec[1], vec[2]
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

    -- Получение нужных адресов памяти
    local settingsPtr = sampGetServerSettingsPtr()
    pointers.nametags.dist = settingsPtr + 39
    pointers.nametags.walls = settingsPtr + 47
    pointers.nametags.show = settingsPtr + 56

    --[[ Инициализация скрипта ]]
    -- Создание папки config, если она не существует
    if not doesDirectoryExist(configDir) then
        createDirectory(configDir)
    end

    -- Загрузка настроек из конфига
    loadSettings()

    -- Создание конфига при первом запуске скрипта
    saveSettings()

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
        for text, cmd in pairs(settings.commands) do
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

        local _, commandsCount = commands:gsub('\n', '')
        local content = string.format(
            -- 0                      1                        2          3
            '%s--- Wallhack в слежке\nКлавиша активации: %s%s\nРежим: %s%s\n \n',
            c(color.yellow), c(color.grey), vkeys.id_to_name(settings.hotkeys.hotkeyWallhack), c(color.grey), wallhackModeName()
        ) .. string.format(
            -- 4                       5                              6                             7                       8
            '%s--- Список нарушителей\nКлавиша открытия списка: %s%s\nКлавиша редактирования: %s%s\nКлавиша удаления: %s%s\n \n',
            c(color.yellow), c(color.grey), vkeys.id_to_name(settings.hotkeys.hotkeySuspectsList),
            c(color.grey), vkeys.id_to_name(settings.hotkeys.hotkeySuspectsEdit),
            c(color.grey), vkeys.id_to_name(settings.hotkeys.hotkeySuspectsDelete)
        ) .. string.format(
            -- 9
            '%s--- Команды %s(%d)\n%s',
            c(color.yellow), c(color.green), commandsCount, commands
        )
        _, dialog.settings.maxListitem = content:gsub('\n', '')

        sampShowDialog(dialog.settings.id, c(color.system) .. 'Управление скриптом ' .. thisScript().name .. ' ' .. thisScript().version, content, 'Выбрать', 'Закрыть', DIALOG_STYLE_LIST)
    end)

    sampRegisterChatCommand('suspects', function ()
        local text = 'Статус\tНикнейм\tКомментарий'

        local list = ''
        for nickname, comment in pairs(settings.suspects) do
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

        if not isEmpty(settings.suspects[lowerNickname]) then
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

    -- Регистрация пользовательских команд
    for text, _ in pairs(settings.commands) do
        sampRegisterChatCommand(text, function (args)
            if not pcall(handleCustomCommand, text, args) then
                sampAddChatMessage(string.format(
                    'Ошибка: %sВо время выполнения команды %q произошла ошибка',
                    c(color.white), text
                ), color.red)
            end
        end)
    end

    -- Регистрация консольных команд
    sampfuncsRegisterConsoleCommand('uah', function (arg)
        if isEmpty(arg) then
            print('uah [[num_]version | suspects | debug | settings]')
        elseif arg == 'debug' then
            debug = not debug

            local state = ''
            if debug then
                state = 'включена'
            else
                state = 'выключена'
            end

            print('Отладка ' .. state)
        elseif arg == 'settings' then
            for name, value in pairs(settings) do
                if type(value) == 'table' then
                    for subname, subvalue in pairs(value) do
                        print(name, ':', subname, '=', subvalue)
                    end
                else
                    print(name, '=', value)
                end
            end
        elseif arg == 'version' then
            print(thisScript().name .. ' ' .. thisScript().version)
        elseif arg == 'num_version' then
            print(tostring(thisScript().version_num))
        elseif arg == 'suspects' then
            for name, comment in pairs(settings.suspects) do
                print(string.format('%q: %q', name, comment))
            end
        elseif arg == 'wallhack' then
            print('Статус WH: ', settings.wallhack.enabled and 'Включён' or 'Выключен')
        end
    end)

    -- Поток для Wallhack-а
    wallhackThread = lua_thread.create_suspended(threadWallhack)
    if settings.wallhack.enabled then
        -- Если Wallhack включён в настройках,
        -- то необходимо запустить поток
        wallhackThread:run()
    end

    -- Главный цикл
    while true do
        wait(0)

        --[[ Обработка нажатий клавиш ]]
        if not sampIsChatInputActive()
            and not sampIsDialogActive()
        then
            if isKeyJustPressed(settings.hotkeys.hotkeySuspectsList) then
                sampProcessChatInput('/suspects')
            elseif isKeyJustPressed(settings.hotkeys.hotkeyWallhack) then
                settings.wallhack.enabled = not settings.wallhack.enabled

                if settings.wallhack.enabled then
                    wallhackThread:run()
                else
                    if settings.wallhack.mode == WALLHACK_MODE_ALL or settings.wallhack.mode == WALLHACK_MODE_NAMES then
                        wallhackToggleNametags(false)
                    end

                    wallhackThread:terminate()
                end
            end
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
                or listitem == 5
                or listitem == 6
                or listitem == 7
            then
                if listitem == 1 then
                    keyCapture.fnc = 'Активация Wallhack в слежке'
                    keyCapture.id = settings.hotkeys.hotkeyWallhack
                    keyCapture.setting = 'hotkeyWallhack'
                elseif listitem == 5 then
                    keyCapture.fnc = 'Открытие списка нарушителей'
                    keyCapture.id = settings.hotkeys.hotkeySuspectsList
                    keyCapture.setting = 'hotkeySuspectsList'
                elseif listitem == 6 then
                    keyCapture.fnc = 'Редактирование записи в списке нарушителей'
                    keyCapture.id = settings.hotkeys.hotkeySuspectsEdit
                    keyCapture.setting = 'hotkeySuspectsEdit'
                elseif listitem == 7 then
                    keyCapture.fnc = 'Удаление из списка нарушителей'
                    keyCapture.id = settings.hotkeys.hotkeySuspectsDelete
                    keyCapture.setting = 'hotkeySuspectsDelete'
                end

                backwardToSettingsFromCurrentDialog = true
                showHotkeyCaptureDialog()
            elseif listitem == 2 then
                toggleWallhackMode()
                sampProcessChatInput('/uah')
            elseif listitem == 0
                or listitem == 3
                or listitem == 4
                or listitem >= 8
            then
                sampProcessChatInput('/uah')
            end
        end

        -- Диалог назначения клавиши
        result, button, listitem = sampHasDialogRespond(dialog.settings.hotkey)
        if result then
            if button == 1 then
                settings.hotkeys[keyCapture.setting] = keyCapture.id
                saveSettings()
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
                    if isKeyJustPressed(settings.hotkeys.hotkeySuspectsDelete) then
                        -- Удаление из списка
                        delSuspect(nickname)
                        sampProcessChatInput('/suspects')
                    elseif isKeyJustPressed(settings.hotkeys.hotkeySuspectsEdit) then
                        -- Изменение комментария
                        sampCloseCurrentDialogWithButton(0)
                        sampProcessChatInput('/su')
                        sampSetChatInputEnabled(true)
                        sampSetChatInputText(string.format('/su %s %s', nickname, settings.suspects[nickname]))
                        suspectsListItemIndex = sampGetCurrentDialogListItem()
                    end
                end
            end
        end
    end

    wallhackThread:terminate()
end

--[[ Функция для отдельного потока для Wallhack ]]
function threadWallhack()
    while not sampIsLocalPlayerSpawned() do wait(1000) end

    nametagsDefaults.dist = mem.getfloat(pointers.nametags.dist)
    nametagsDefaults.walls = mem.getint8(pointers.nametags.walls)
    nametagsDefaults.show = mem.getint8(pointers.nametags.show)

    if settings.wallhack.enabled and (settings.wallhack.mode == WALLHACK_MODE_ALL or settings.wallhack.mode == WALLHACK_MODE_NAMES) then
        wallhackToggleNametags(true)
    end

    while true do
        wait(0)

        if settings.wallhack.enabled and not isPauseMenuActive() and not isKeyDown(vkeys.VK_F8) and not sampIsDialogActive() then
            if settings.wallhack.mode == WALLHACK_MODE_ALL or settings.wallhack.mode == WALLHACK_MODE_BONES then
                for id = 0, sampGetMaxPlayerId() do
                    if sampIsPlayerConnected(id) then
                        local result, ped = sampGetCharHandleBySampPlayerId(id)
                        local color = sampGetPlayerColor(id)
                        local a, r, g, b = explode_argb(color)
                        color = join_argb(255, r, g, b)

                        if result and doesCharExist(ped) and isCharOnScreen(ped) then
                            local pos1x, pos1y, pos1z

                            for idx = 1, #wallhackBodyParts do
                                pos1x, pos1y, pos1z = getBodyPartCoordinates(wallhackBodyParts[idx], ped)
                                local pos2x, pos2y, pos2z = getBodyPartCoordinates(wallhackBodyParts[idx] + 1, ped)

                                local screenPos1x, screenPos1y = convert3DCoordsToScreen(pos1x, pos1y, pos1z)
                                local screenPos2x, screenPos2y = convert3DCoordsToScreen(pos2x, pos2y, pos2z)

                                renderDrawLine(screenPos1x, screenPos1y, screenPos2x, screenPos2y, 1, color)

                                if idx == 4 or idx == 5 then
                                    pos2x, pos2y, pos2z = getBodyPartCoordinates(idx * 10 + 1, ped)
                                    screenPos2x, screenPos2y = convert3DCoordsToScreen(pos2x, pos2y, pos2z)

                                    renderDrawLine(screenPos1x, screenPos1y, screenPos2x, screenPos2y, 1, color)
                                end
                            end
                        end
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
