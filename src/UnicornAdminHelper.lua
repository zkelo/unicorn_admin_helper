--[[ Зависимости ]]
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local samp = require 'samp.events'

--[[ Переменные и значения по умолчанию ]]
encoding.default = 'utf-8'
local cp1251 = encoding.cp1251

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
        list = 1
    }
}

local suspects = {}

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
function _(text)
    return cp1251:encode(text)
end

function __(text)
    return cp1251:decode(text)
end

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
    data.suspects:remove(name)
    saveData()
end

function c(color)
    return '{' .. string.format('%x', color) .. '}'
end

function isEmpty(var)
    return var == nil or #var == 0
end

--[[ Метаданные ]]
script_name('Unicorn Admin Helper')
script_author('ZKelo')
script_description(_('Скрипт в помощь администратору игрового сервера Unicorn'))
script_version('2.0.5')
script_version_number(5)
script_moonloader(26)
script_dependencies('encoding', 'samp')

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
    sampAddChatMessage(_(thisScript().name .. ' ' .. thisScript().version .. ' успешно загружен'), color.system)
    sampAddChatMessage(_('Для просмотра справки введите /uah'), color.yellow)

    -- Регистрация команд чата
    sampRegisterChatCommand('suspects', function ()
        local text = 'Статус\tНикнейм\tКомментарий'

        local list = ''
        for nickname, comment in pairs(data.suspects) do
            local status = c(color.red) .. 'Оффлайн'

            list = list .. '\n' .. status .. '\t' .. nickname .. '\t' .. comment
        end

        if isEmpty(list) then
            list = '\nСписок пуст\t\t'
        end

        sampShowDialog(dialog.suspects.list, _('Список нарушителей'), _(text .. list), _('Действия'), _('Закрыть'), DIALOG_STYLE_TABLIST_HEADERS)
    end)

    sampRegisterChatCommand('su', function (args)
        local hint = _('Подсказка: ' .. c(color.white) ..'/su ' .. c(color.lightGrey) .. '[никнейм] [Комментарий (необязательно)] ' .. c(color.grey) .. '(добавить игрока в список нарушителей)')

        if isEmpty(args) then
            sampAddChatMessage(hint, color.green)
            return
        end

        nickname, comment = args:match('(.*)%s*(.*)')

        if isEmpty(nickname) then
            sampAddChatMessage(hint, color.green)
            return
        end

        nickname = __(nickname)
        if not isEmpty(data.suspects[nickname]) then
            delSuspect(nickname)
        end

        if not isEmpty(comment) then
            comment = __(comment)
            addSuspect(nickname, comment)
            sampAddChatMessage(_('Список нарушителей обновлён'), color.grey)
            return
        end

        comment = c(color.lightGrey) .. '(не указан)'
        addSuspect(nickname, comment)
        sampAddChatMessage(_('Список нарушителей обновлён'), color.grey)
    end)

    sampRegisterChatCommand('delsu', function (nickname)
        if isEmpty(nickname) then
            sampAddChatMessage(_('Подсказка: ' .. c(color.white) .. '/delsu ' .. c(color.lightGrey) .. '[никнейм] ' .. c(color.grey) .. '(удалить игрока из списка нарушителей)'), color.green)
            return
        end

        delSuspect(nickname)
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
                print(_(string.format('%q: %q', name, comment)))
            end
        end
    end)

    -- Главный цикл
    while true do
        wait(500)
        --[[ TODO ]]
    end
end

--[[ Обработчики событий ]]
function samp.onSendCommand(command)
    -- Здесь должен быть обработчик команд
    -- с возможностью добавления собственных
end
