--------------------------------------------------
-- BlackJack
-- ui/renderer.lua
--------------------------------------------------

local component = require("component")
local unicode = require("unicode")

local renderer = {}


--------------------------------------------------
-- GPU
--------------------------------------------------

if component.isAvailable("gpu") then

    renderer.gpu =
        component.gpu

else

    error("GPU not found")

end


local gpu =
    renderer.gpu


--------------------------------------------------
-- Размер экрана
--------------------------------------------------

function renderer.getResolution()

    return gpu.getResolution()

end


--------------------------------------------------
-- Сброс цветов
--------------------------------------------------

function renderer.resetColor()

    gpu.setBackground(0x000000)

    gpu.setForeground(0xFFFFFF)

end


--------------------------------------------------
-- Очистка
--------------------------------------------------

function renderer.clear(color)

    local w, h =
        gpu.getResolution()


    gpu.setBackground(

        color or 0x202020

    )


    gpu.fill(

        1,

        1,

        w,

        h,

        " "

    )

end


--------------------------------------------------
-- Текст
--------------------------------------------------

function renderer.text(
    x,
    y,
    text,
    color,
    background
)


    if background then

        gpu.setBackground(background)

    end


    gpu.setForeground(

        color or 0xFFFFFF

    )


    gpu.set(

        x,

        y,

        tostring(text)

    )


end


--------------------------------------------------
-- Центрированный текст
--------------------------------------------------

function renderer.center(
    y,
    text,
    color,
    background
)


    local width =
        gpu.getResolution()


    local len =
        unicode.len(
            tostring(text)
        )


    local x =
        math.floor(
            (width - len) / 2
        ) + 1


    renderer.text(

        x,

        y,

        text,

        color,

        background

    )

end


--------------------------------------------------
-- Панель
--------------------------------------------------

function renderer.panel(
    x,
    y,
    width,
    height,
    color
)


    gpu.setBackground(color)


    gpu.fill(

        x,

        y,

        width,

        height,

        " "

    )

end


--------------------------------------------------
-- Горизонтальная линия
--------------------------------------------------

function renderer.hLine(
    x,
    y,
    width,
    color
)

    gpu.setForeground(

        color or 0xFFFFFF

    )


    gpu.set(

        x,

        y,

        ("─"):rep(width)

    )

end


--------------------------------------------------
-- Вертикальная линия
--------------------------------------------------

function renderer.vLine(
    x,
    y,
    height,
    color
)


    gpu.setForeground(

        color or 0xFFFFFF

    )


    for i = 0, height - 1 do

        gpu.set(

            x,

            y + i,

            "│"

        )

    end

end


--------------------------------------------------
-- Рамка
--------------------------------------------------

function renderer.border(
    x,
    y,
    width,
    height,
    color
)


    gpu.setForeground(

        color or 0xFFFFFF

    )


    renderer.hLine(

        x + 1,

        y,

        width - 2,

        color

    )


    renderer.hLine(

        x + 1,

        y + height - 1,

        width - 2,

        color

    )


    renderer.vLine(

        x,

        y + 1,

        height - 2,

        color

    )


    renderer.vLine(

        x + width - 1,

        y + 1,

        height - 2,

        color

    )


    gpu.set(x, y, "┌")

    gpu.set(
        x + width - 1,
        y,
        "┐"
    )

    gpu.set(
        x,
        y + height - 1,
        "└"
    )

    gpu.set(
        x + width - 1,
        y + height - 1,
        "┘"
    )

end


--------------------------------------------------
-- Кнопка
--------------------------------------------------

function renderer.button(
    x,
    y,
    width,
    height,
    text
)


    renderer.panel(

        x,

        y,

        width,

        height,

        0x3A3A3A

    )


    renderer.border(

        x,

        y,

        width,

        height,

        0xFFD700

    )


    local tx =

        x +

        math.floor(

            (width -
            unicode.len(text))

            / 2

        )


    local ty =

        y +

        math.floor(

            height / 2

        )


    renderer.text(

        tx,

        ty,

        text,

        0xFFFFFF

    )


end


--------------------------------------------------
-- Прогресс
--------------------------------------------------

function renderer.progress(
    x,
    y,
    width,
    percent,
    backColor,
    fillColor
)


    percent =
        math.max(
            0,
            math.min(
                100,
                percent
            )
        )


    renderer.panel(

        x,

        y,

        width,

        1,

        backColor or 0x444444

    )


    local filled =

        math.floor(

            width *

            percent /

            100

        )


    if filled > 0 then

        renderer.panel(

            x,

            y,

            filled,

            1,

            fillColor or 0x00AA00

        )

    end


end


--------------------------------------------------

return renderer