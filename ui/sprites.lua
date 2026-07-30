--------------------------------------------------
-- BlackJack
-- ui/sprites.lua
--------------------------------------------------

local renderer = require("ui.renderer")

local theme = require("ui.theme")

local sprites = {}


--------------------------------------------------
-- Пиксельная карта
--------------------------------------------------

sprites.card = {

    width = 7,

    height = 5

}



--------------------------------------------------
-- Шаблон рубашки карты
--------------------------------------------------

sprites.back = {

    "+++++++",

    "+.....+",

    "+.....+",

    "+.....+",

    "+++++++"

}



--------------------------------------------------
-- Шаблон пустой карты
--------------------------------------------------

sprites.empty = {

    "       ",

    "       ",

    "       ",

    "       ",

    "       "

}



--------------------------------------------------
-- Масти
--------------------------------------------------

sprites.suits = {

    hearts = "♥",

    diamonds = "♦",

    clubs = "♣",

    spades = "♠"

}



--------------------------------------------------
-- Цвет масти
--------------------------------------------------

function sprites.suitColor(suit)

    if suit == "hearts"
    or suit == "diamonds" then

        return theme.colors.heart

    end


    return theme.colors.club

end



--------------------------------------------------
-- Рисование рубашки
--------------------------------------------------

function sprites.drawBack(x, y)


    renderer.panel(

        x,

        y,

        sprites.card.width,

        sprites.card.height,

        theme.card.back

    )



    renderer.border(

        x,

        y,

        sprites.card.width,

        sprites.card.height,

        theme.colors.gold

    )


end



--------------------------------------------------
-- Рисование карты
--------------------------------------------------

function sprites.drawCard(
    x,
    y,
    value,
    suit
)


    renderer.panel(

        x,

        y,

        sprites.card.width,

        sprites.card.height,

        theme.card.background

    )



    renderer.border(

        x,

        y,

        sprites.card.width,

        sprites.card.height,

        theme.card.border

    )



    local symbol =

        sprites.suits[suit]

        or

        "?"



    local color =

        sprites.suitColor(suit)



    renderer.text(

        x + 1,

        y + 1,

        tostring(value),

        color

    )



    renderer.text(

        x + 3,

        y + 3,

        symbol,

        color

    )


end



--------------------------------------------------
-- Анимация появления карты
--------------------------------------------------

function sprites.reveal(
    x,
    y,
    value,
    suit
)


    sprites.drawBack(

        x,

        y

    )


    os.sleep(

        0.3

    )


    sprites.drawCard(

        x,

        y,

        value,

        suit

    )


end



--------------------------------------------------
-- Пиксельные масти
--------------------------------------------------

sprites.pixelSuits = {}


sprites.pixelSuits.hearts = {

"..RR..",

".RRRR.",

"RRRRRR",

"RRRRRR",

".RRRR.",

"..RR..",

"...R.."

}



sprites.pixelSuits.diamonds = {

"...R..",

"..RR..",

".RRRR.",

"RRRRRR",

".RRRR.",

"..RR..",

"...R.."

}



sprites.pixelSuits.clubs = {

"..GG..",

".GGGG.",

"..GG..",

"GGGGGG",

"..GG..",

".GGGG.",

"...G.."

}



sprites.pixelSuits.spades = {

"...G..",

"..GG..",

".GGGG.",

"GGGGGG",

"..GG..",

"..GG..",

"...G.."

}



--------------------------------------------------
-- Палитра
--------------------------------------------------

sprites.palette = {

    R = 0xCC3333,

    G = 0x111111

}



--------------------------------------------------

return sprites