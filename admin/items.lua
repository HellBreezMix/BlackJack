--------------------------------------------------
-- BlackJack
-- admin/items.lua
--------------------------------------------------

local storage = require("lib.storage")
local config = require("config")

local items = {}

--------------------------------------------------
-- Список предметов
--------------------------------------------------

items.list = {}

--------------------------------------------------
-- Загрузка
--------------------------------------------------

function items.load()

    local data =
        storage.load(
            config.paths.items
        )


    if data then

        items.list = data

    else

        items.list = {}

        items.save()

    end

end

--------------------------------------------------
-- Сохранение
--------------------------------------------------

function items.save()

    storage.save(

        config.paths.items,

        items.list

    )

end

--------------------------------------------------
-- Добавить предмет
--------------------------------------------------

function items.add(name, label)

    if not name then

        return false

    end


    if items.exists(name) then

        return false

    end


    table.insert(

        items.list,

        {

            name = name,

            label = label or name,

            enabled = true

        }

    )


    items.save()


    return true

end

--------------------------------------------------
-- Удалить предмет
--------------------------------------------------

function items.remove(name)

    for i, item in ipairs(
        items.list
    ) do

        if item.name == name then

            table.remove(

                items.list,

                i

            )


            items.save()


            return true

        end

    end


    return false

end

--------------------------------------------------
-- Проверка предмета
--------------------------------------------------

function items.exists(name)

    for _, item in ipairs(
        items.list
    ) do

        if item.name == name then

            return true

        end

    end


    return false

end

--------------------------------------------------
-- Получить предмет
--------------------------------------------------

function items.get(name)

    for _, item in ipairs(
        items.list
    ) do

        if item.name == name then

            return item

        end

    end


    return nil

end

--------------------------------------------------
-- Получить список
--------------------------------------------------

function items.getAll()

    return items.list

end

--------------------------------------------------
-- Включить предмет
--------------------------------------------------

function items.enable(name)

    local item =
        items.get(name)


    if item then

        item.enabled = true

        items.save()

        return true

    end


    return false

end

--------------------------------------------------
-- Отключить предмет
--------------------------------------------------

function items.disable(name)

    local item =
        items.get(name)


    if item then

        item.enabled = false

        items.save()

        return true

    end


    return false

end

--------------------------------------------------

return items