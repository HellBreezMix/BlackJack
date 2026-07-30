--------------------------------------------------
-- BlackJack
-- ui/animation.lua
--------------------------------------------------

local theme = require("ui.theme")

local animation = {}


--------------------------------------------------
-- Ожидание
--------------------------------------------------

function animation.wait(time)

    if not theme.animation.enabled then

        return

    end


    os.sleep(time)

end


--------------------------------------------------
-- Задержка карты
--------------------------------------------------

function animation.cardDelay()

    animation.wait(
        theme.animation.cardDelay
    )

end


--------------------------------------------------
-- Плавная задержка
--------------------------------------------------

function animation.transition()

    animation.wait(
        theme.animation.transition
    )

end


--------------------------------------------------
-- Анимация появления текста
--------------------------------------------------

function animation.text(callback)

    if not theme.animation.enabled then

        callback()

        return

    end


    animation.transition()


    callback()

end


--------------------------------------------------
-- Анимация карты
--------------------------------------------------

function animation.card(callback)

    if not theme.animation.enabled then

        callback()

        return

    end


    animation.cardDelay()


    callback()

end


--------------------------------------------------
-- Серия действий
--------------------------------------------------

function animation.sequence(actions)

    for _, action in ipairs(actions) do

        action()

        animation.transition()

    end

end


--------------------------------------------------

return animation