--------------------------------------------------
-- BlackJack
-- ui/theme.lua
--------------------------------------------------

local theme = {}

--------------------------------------------------
-- Основные цвета
--------------------------------------------------

theme.colors = {

    background = 0x101010,

    panel = 0x1C1C1C,

    panelLight = 0x252525,


    text = 0xFFFFFF,

    textDark = 0xAAAAAA,


    gold = 0xFFD700,


    green = 0x00AA55,

    red = 0xCC3333,

    blue = 0x3366CC,


    button = 0x333333,

    buttonHover = 0x555555,


    card = 0xFFFFFF,

    cardBack = 0x990000,


    heart = 0xCC0000,

    diamond = 0xCC0000,

    club = 0x111111,

    spade = 0x111111

}

--------------------------------------------------
-- Размеры интерфейса
--------------------------------------------------

theme.size = {

    headerHeight = 3,

    footerHeight = 2,


    buttonHeight = 3,

    buttonWidth = 14,


    cardWidth = 7,

    cardHeight = 5,


    padding = 1

}

--------------------------------------------------
-- Стиль кнопок
--------------------------------------------------

theme.button = {

    normal = {

        background =
            theme.colors.button,

        text =
            theme.colors.text

    },


    hover = {

        background =
            theme.colors.buttonHover,

        text =
            theme.colors.gold

    }

}

--------------------------------------------------
-- Стиль карт
--------------------------------------------------

theme.card = {

    background =
        theme.colors.card,


    border =
        0x555555,


    back =
        theme.colors.cardBack

}

--------------------------------------------------
-- Анимации
--------------------------------------------------

theme.animation = {

    enabled = true,


    cardDelay = 0.15,


    transition = 0.2

}

--------------------------------------------------
-- Шрифт
--------------------------------------------------

theme.font = {

    title = 2,

    normal = 1

}

--------------------------------------------------

return theme