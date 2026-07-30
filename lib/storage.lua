--------------------------------------------------
-- BlackJack
-- lib/storage.lua
--------------------------------------------------

local filesystem = require("filesystem")
local serialization = require("serialization")

local storage = {}

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
-- Проверка существования
--------------------------------------------------

function storage.exists(path)

    return filesystem.exists(path)

end

--------------------------------------------------
-- Загрузка
--------------------------------------------------

function storage.load(path)

    if not filesystem.exists(path) then
        return nil
    end

    local file = io.open(path, "r")

    if not file then
        return nil
    end

    local content = file:read("*a")

    file:close()

    if not content or content == "" then
        return nil
    end

    local ok, data =
        pcall(serialization.unserialize, content)

    if ok then
        return data
    end

    return nil

end

--------------------------------------------------
-- Сохранение
--------------------------------------------------

function storage.save(path, data)

    ensureDirectory(path)

    local file = io.open(path, "w")

    if not file then
        return false
    end

    local ok, serialized =
        pcall(serialization.serialize, data)

    if not ok then
        file:close()
        return false
    end

    file:write(serialized)

    file:close()

    return true

end

--------------------------------------------------
-- Создать файл
--------------------------------------------------

function storage.create(path, defaultData)

    if filesystem.exists(path) then
        return true
    end

    return storage.save(path, defaultData or {})

end

--------------------------------------------------
-- Получить таблицу
--------------------------------------------------

function storage.get(path)

    return storage.load(path) or {}

end

--------------------------------------------------
-- Обновить
--------------------------------------------------

function storage.update(path, callback)

    local data =
        storage.get(path)

    callback(data)

    return storage.save(path, data)

end

--------------------------------------------------
-- Добавить запись
--------------------------------------------------

function storage.insert(path, value)

    return storage.update(path, function(data)

        table.insert(data, value)

    end)

end

--------------------------------------------------
-- Очистить
--------------------------------------------------

function storage.clear(path)

    return storage.save(path, {})

end

--------------------------------------------------
-- Удалить
--------------------------------------------------

function storage.delete(path)

    if filesystem.exists(path) then
        filesystem.remove(path)
    end

end

--------------------------------------------------
-- Добавить текст
--------------------------------------------------

function storage.append(path, text)

    ensureDirectory(path)

    local file = io.open(path, "a")

    if not file then
        return false
    end

    file:write(text)

    file:close()

    return true

end

--------------------------------------------------

return storage