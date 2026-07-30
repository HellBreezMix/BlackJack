--------------------------------------------------
-- BlackJack
-- ui/pixel.lua
--------------------------------------------------

local component = require("component")

local gpu = component.gpu

local pixel = {}

--------------------------------------------------
-- Нарисовать пиксель
--------------------------------------------------

function pixel.dot(x, y, color)

    gpu.setBackground(color)
    gpu.fill(x, y, 1, 1, " ")

end

--------------------------------------------------
-- Нарисовать массив пикселей
--------------------------------------------------

function pixel.draw(x, y, sprite, palette)

    for row = 1, #sprite do

        local line = sprite[row]

        for col = 1, #line do

            local symbol = line:sub(col, col)

            local color = palette[symbol]

            if color then

                pixel.dot(

                    x + col - 1,

                    y + row - 1,

                    color

                )

            end

        end

    end

end

--------------------------------------------------
-- Отразить по горизонтали
--------------------------------------------------

function pixel.flip(sprite)

    local result = {}

    for i = 1, #sprite do

        result[i] = sprite[i]:reverse()

    end

    return result

end

--------------------------------------------------
-- Масштабирование ×2
--------------------------------------------------

function pixel.scale2(sprite)

    local result = {}

    for _, line in ipairs(sprite) do

        local expanded = ""

        for i = 1, #line do

            local c = line:sub(i, i)

            expanded = expanded .. c .. c

        end

        table.insert(result, expanded)
        table.insert(result, expanded)

    end

    return result

end

--------------------------------------------------

return pixel