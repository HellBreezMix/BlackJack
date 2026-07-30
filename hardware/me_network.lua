--------------------------------------------------
-- BlackJack
-- hardware/me_network.lua
--------------------------------------------------

local component = require("component")

local me = {}

--------------------------------------------------
-- Проверка
--------------------------------------------------

me.available = component.isAvailable("me_interface")

if me.available then

    me.interface = component.me_interface

end

--------------------------------------------------
-- Подключено ли
--------------------------------------------------

function me.isAvailable()

    return me.available

end

--------------------------------------------------
-- Список предметов
--------------------------------------------------

function me.list()

    if not me.available then
        return {}
    end

    return me.interface.getItemsInNetwork()

end

--------------------------------------------------
-- Поиск предмета
--------------------------------------------------

function me.find(database)

    if not me.available then
        return nil
    end

    return me.interface.getItemsInNetwork(database)

end

--------------------------------------------------
-- Есть ли предмет
--------------------------------------------------

function me.has(database, amount)

    local items =
        me.find(database)

    if not items then
        return false
    end

    if #items == 0 then
        return false
    end

    return items[1].size >= amount

end

--------------------------------------------------
-- Забрать предмет
--------------------------------------------------

function me.export(database, amount, side)

    if not me.available then
        return false
    end

    local moved =
        me.interface.exportItem(

            database,

            side,

            amount

        )

    return moved > 0

end

--------------------------------------------------
-- Положить предмет
--------------------------------------------------

function me.import(side, slot, amount)

    if not me.available then
        return false
    end

    local moved =
        me.interface.importItem(

            side,

            slot,

            amount

        )

    return moved > 0

end

--------------------------------------------------

return me