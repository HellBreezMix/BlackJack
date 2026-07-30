--------------------------------------------------
-- BlackJack
-- hardware/transposer.lua
--------------------------------------------------

local component = require("component")

local transposer = {}

--------------------------------------------------

transposer.available =
    component.isAvailable("transposer")

if transposer.available then

    transposer.tp =
        component.transposer

end

--------------------------------------------------
-- Проверка
--------------------------------------------------

function transposer.isAvailable()

    return transposer.available

end

--------------------------------------------------
-- Предмет в слоте
--------------------------------------------------

function transposer.getStack(side, slot)

    if not transposer.available then
        return nil
    end

    return transposer.tp.getStackInSlot(

        side,

        slot

    )

end

--------------------------------------------------
-- Количество слотов
--------------------------------------------------

function transposer.getSlots(side)

    if not transposer.available then
        return 0
    end

    return transposer.tp.getInventorySize(side)

end

--------------------------------------------------
-- Переместить
--------------------------------------------------

function transposer.move(from, to, amount, slot)

    if not transposer.available then
        return 0
    end

    return transposer.tp.transferItem(

        from,

        to,

        amount,

        slot

    )

end

--------------------------------------------------

return transposer