--------------------------------------------------
-- BlackJack
-- ui/widgets.lua
--------------------------------------------------

local renderer = require("ui.renderer")

local theme = require("ui.theme")

local widgets = {}

--------------------------------------------------
-- Кнопка
--------------------------------------------------

function widgets.button(
    x,
    y,
    width,
    height,
    text,
    callback
)

    local button = {

        x = x,

        y = y,

        width = width,

        height = height,

        text = text,

        callback = callback,

        active = true

    }


    function button.draw()

        if button.active then

            renderer.button(

                button.x,

                button.y,

                button.width,

                button.height,

                button.text

            )

        end

    end



    function button.click(px, py)

        if not button.active then

            return false

        end



        if px >= button.x
        and px < button.x + button.width
        and py >= button.y
        and py < button.y + button.height then


            if button.callback then

                button.callback()

            end


            return true

        end


        return false

    end



    function button.enable()

        button.active = true

    end



    function button.disable()

        button.active = false

    end



    return button

end


--------------------------------------------------
-- Панель
--------------------------------------------------

function widgets.panel(
    x,
    y,
    width,
    height,
    title
)

    local panel = {

        x = x,

        y = y,

        width = width,

        height = height,

        title = title

    }



    function panel.draw()


        renderer.panel(

            panel.x,

            panel.y,

            panel.width,

            panel.height,

            theme.colors.panel

        )



        renderer.border(

            panel.x,

            panel.y,

            panel.width,

            panel.height,

            theme.colors.gold

        )



        if panel.title then

            renderer.text(

                panel.x + 2,

                panel.y,

                panel.title,

                theme.colors.gold

            )

        end


    end



    return panel

end


--------------------------------------------------
-- Область карт
--------------------------------------------------

function widgets.cardArea(
    x,
    y,
    title
)

    local area = {

        x = x,

        y = y,

        title = title,

        cards = {}

    }



    function area.setCards(cards)

        area.cards = cards or {}

    end



    function area.draw()


        renderer.text(

            area.x,

            area.y,

            area.title,

            theme.colors.gold

        )



        local offset = 0



        for _, card in ipairs(area.cards) do


            renderer.panel(

                area.x + offset,

                area.y + 1,

                theme.size.cardWidth,

                theme.size.cardHeight,

                theme.colors.card

            )



            renderer.border(

                area.x + offset,

                area.y + 1,

                theme.size.cardWidth,

                theme.size.cardHeight,

                theme.colors.gold

            )



            renderer.text(

                area.x + offset + 2,

                area.y + 3,

                tostring(card),

                theme.colors.club

            )



            offset =
                offset +
                theme.size.cardWidth + 1


        end


    end



    return area

end


--------------------------------------------------
-- Сообщение
--------------------------------------------------

function widgets.message(text)

    local box = {

        text = text

    }



    function box.draw()


        local width, height =
            renderer.getResolution()



        renderer.panel(

            5,

            5,

            width - 10,

            5,

            theme.colors.panelLight

        )



        renderer.border(

            5,

            5,

            width - 10,

            5,

            theme.colors.gold

        )



        renderer.center(

            7,

            box.text,

            theme.colors.text

        )


    end



    return box

end


--------------------------------------------------
-- Ставка
--------------------------------------------------

function widgets.betBox()

    local bet = {

        value = 0

    }



    function bet.set(value)

        bet.value = tonumber(value) or 0

    end



    function bet.add(value)

        bet.value =
            bet.value + (tonumber(value) or 0)

    end



    function bet.get()

        return bet.value

    end



    function bet.draw(x, y)

        renderer.text(

            x,

            y,

            "BET: " .. tostring(bet.value),

            theme.colors.gold

        )

    end



    return bet

end


--------------------------------------------------
-- Текстовый заголовок
--------------------------------------------------

function widgets.title(text)

    local label = {

        text = text

    }



    function label.draw(y)

        renderer.center(

            y or 2,

            label.text,

            theme.colors.gold

        )

    end



    return label

end


--------------------------------------------------
-- Индикатор результата
--------------------------------------------------

function widgets.result(text, color)

    local result = {

        text = text,

        color = color or theme.colors.gold

    }



    function result.draw(y)

        renderer.center(

            y or 18,

            result.text,

            result.color

        )

    end



    return result

end


--------------------------------------------------

return widgets