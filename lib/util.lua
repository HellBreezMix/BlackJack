--------------------------------------------------
-- BlackJack
-- lib/util.lua
--------------------------------------------------

local filesystem = require("filesystem")
local unicode = require("unicode")

local util = {}

--------------------------------------------------
-- Создать директорию
--------------------------------------------------

local function ensureDirectory(path)

    local dir = filesystem.path(path)

    if dir and dir ~= "" and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
    end

end

--------------------------------------------------
-- Проверка существования файла
--------------------------------------------------

function util.fileExists(path)

    return filesystem.exists(path)

end

--------------------------------------------------
-- Чтение файла
--------------------------------------------------

function util.readFile(path)

    local file = io.open(path, "r")

    if not file then
        return nil
    end

    local data = file:read("*a")

    file:close()

    return data

end

--------------------------------------------------
-- Запись файла
--------------------------------------------------

function util.writeFile(path, data)

    ensureDirectory(path)

    local file = io.open(path, "w")

    if not file then
        return false
    end

    file:write(data)

    file:close()

    return true

end

--------------------------------------------------
-- Добавление в файл
--------------------------------------------------

function util.appendFile(path, data)

    ensureDirectory(path)

    local file = io.open(path, "a")

    if not file then
        return false
    end

    file:write(data)

    file:close()

    return true

end

--------------------------------------------------
-- Глубокое копирование
--------------------------------------------------

function util.copyTable(tbl)

    local copy = {}

    for k, v in pairs(tbl) do

        if type(v) == "table" then
            copy[k] = util.copyTable(v)
        else
            copy[k] = v
        end

    end

    return copy

end

--------------------------------------------------
-- Ограничение
--------------------------------------------------

function util.clamp(value, minimum, maximum)

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value

end

--------------------------------------------------
-- Округление
--------------------------------------------------

function util.round(number)

    return math.floor(number + 0.5)

end

--------------------------------------------------
-- Центрирование текста
--------------------------------------------------

function util.center(text, width)

    local offset =
        math.floor(
            (width - unicode.len(text)) / 2
        )

    if offset < 0 then
        offset = 0
    end

    return offset

end

--------------------------------------------------
-- Есть ли значение
--------------------------------------------------

function util.contains(tbl, value)

    for _, v in pairs(tbl) do

        if v == value then
            return true
        end

    end

    return false

end

--------------------------------------------------
-- Удалить пробелы
--------------------------------------------------

function util.trim(text)

    return text:match("^%s*(.-)%s*$")

end

--------------------------------------------------
-- Разделить строку
--------------------------------------------------

function util.split(text, separator)

    separator = separator or ","

    local result = {}

    for part in string.gmatch(text, "([^"..separator.."]+)") do
        table.insert(result, util.trim(part))
    end

    return result

end

--------------------------------------------------
-- Начинается ли строка
--------------------------------------------------

function util.startsWith(text, start)

    return text:sub(1, #start) == start

end

--------------------------------------------------
-- Время
--------------------------------------------------

function util.time()

    return os.date("%H:%M:%S")

end

--------------------------------------------------
-- Дата
--------------------------------------------------

function util.date()

    return os.date("%d.%m.%Y")

end

--------------------------------------------------

return util