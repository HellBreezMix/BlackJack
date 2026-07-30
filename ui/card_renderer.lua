--------------------------------------------------
-- BlackJack
-- ui/card_renderer.lua
--------------------------------------------------

local face = require("ui.card_faces")
local renderer = require("ui.renderer")

local cards = {}

--------------------------------------------------
-- Размер карты
--------------------------------------------------

cards.width = 11
cards.height = 9


--------------------------------------------------
-- Цвета
--------------------------------------------------

cards.colors = {

    background = 0xF5F5F5,

    border = 0x404040,

    textBlack = 0x111111,

    textRed = 0xCC3333,

    back = 0x204080

}


--------------------------------------------------
-- Символ масти
--------------------------------------------------

local suitSymbol = {

    hearts = "♥",

    diamonds = "♦",

    clubs = "♣",

    spades = "♠"

}


--------------------------------------------------
-- Цвет значения
--------------------------------------------------

function cards.valueColor(suit)

    if suit == "hearts"
    or suit == "diamonds" then

        return cards.colors.textRed

    end

    return cards.colors.textBlack

end


--------------------------------------------------
-- Основа карты
--------------------------------------------------

function cards.base(x, y)

    renderer.panel(

        x,
        y,
        cards.width,
        cards.height,
        cards.colors.background

    )


    renderer.border(

        x,
        y,
        cards.width,
        cards.height,
        cards.colors.border

    )

end


--------------------------------------------------
-- Рубашка
--------------------------------------------------

function cards.back(x,y)

    renderer.panel(

        x,
        y,
        cards.width,
        cards.height,
        cards.colors.back

    )


    renderer.border(

        x,
        y,
        cards.width,
        cards.height,
        0xFFD700

    )

end


--------------------------------------------------
-- Открытая карта
--------------------------------------------------

function cards.draw(x,y,value,suit)


    cards.base(x,y)


    local color =
        cards.valueColor(suit)



    renderer.text(

        x + 1,

        y + 1,

        tostring(value),

        color

    )



    renderer.text(

        x + 1,

        y + 2,

        suitSymbol[suit] or "?",

        color

    )



    if face.figure[value] then


        renderer.center(

            y + 5,

            face.figure[value],

            color

        )


    else


        renderer.center(

            y + 5,

            suitSymbol[suit] or "?",

            color

        )


    end



    renderer.text(

        x + 8,

        y + 7,

        tostring(value),

        color

    )


end


--------------------------------------------------
-- Рука игрока
--------------------------------------------------

function cards.drawHand(hand,x,y)


    local offset = 0


    for _,card in ipairs(hand) do


        cards.draw(

            x + offset,

            y,

            card.rank,

            card.suit

        )


        offset =
            offset + cards.width + 1


    end

end


--------------------------------------------------
-- Карты дилера
--------------------------------------------------

function cards.drawDealer(hand,x,y,hideFirst)


    local offset = 0


    for i,card in ipairs(hand) do


        if i == 1 and hideFirst then


            cards.back(

                x + offset,

                y

            )


        else


            cards.draw(

                x + offset,

                y,

                card.rank,

                card.suit

            )


        end


        offset =
            offset + cards.width + 1


    end

end


--------------------------------------------------

return cards