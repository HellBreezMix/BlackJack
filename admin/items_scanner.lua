--------------------------------------------------
-- BlackJack
-- admin/item_scanner.lua
--------------------------------------------------

local component = require("component")

local scanner = {}

--------------------------------------------------
-- Transposer
--------------------------------------------------

scanner.device = nil

--------------------------------------------------
-- Сторона сундука
--------------------------------------------------

scanner.chestSide = nil

--------------------------------------------------
-- Инициализация
--------------------------------------------------

function scanner.init(side)

    if not component.isAvailable("transposer") then

        return false

    end


    scanner.device =
        component.transposer


    scanner.chestSide = side


    return true

end

--------------------------------------------------
-- Проверка подключения
--------------------------------------------------

function scanner.isReady()

    return scanner.device ~= nil
    and scanner.chestSide ~= nil

end

--------------------------------------------------
-- Получить первый предмет
--------------------------------------------------

function scanner.getItem()

    if not scanner.isReady() then

        return nil

    end


    local stack =
        scanner.device.getStackInSlot(
            scanner.chestSide,
            1
        )


    if not stack then

        return nil

    end


    return {

        name = stack.name,

        label = stack.label,

        damage = stack.damage,

        size = stack.size

    }

end

--------------------------------------------------
-- Проверка наличия предмета
--------------------------------------------------

function scanner.hasItem()

    return scanner.getItem() ~= nil

end

--------------------------------------------------
-- Очистить слот
--------------------------------------------------

function scanner.removeItem()

    if not scanner.isReady() then

        return false

    end


    local stack =
        scanner.device.getStackInSlot(
            scanner.chestSide,
            1
        )


    if not stack then

        return false

    end


    scanner.device.transferItem(
        scanner.chestSide,
        0,
        stack.size,
        1
    )


    return true

end

--------------------------------------------------
-- Ожидание предмета
--------------------------------------------------

function scanner.wait()

    while true do

        local item =
            scanner.getItem()


        if item then

            return item

        end


        os.sleep(1)

    end

end

--------------------------------------------------

return scanner