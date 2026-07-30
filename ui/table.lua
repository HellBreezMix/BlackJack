--------------------------------------------------
-- BlackJack
-- ui/table.lua
--------------------------------------------------

local renderer = require("ui.renderer")

local theme = require("ui.theme")

local tableView = {}

--------------------------------------------------
-- Цвета
--------------------------------------------------

tableView.colors = {

    felt =
        theme.colors.table,

    border =
        0x8B6914,

    shadow =
        0x2B2B2B,

    text =
        0xF8F2C9,

    line =
        theme.colors.gold

}

--------------------------------------------------
-- Игровой стол
--------------------------------------------------

function tableView.draw()


    local width, height =
        renderer.getResolution()



    --------------------------------------------------
    -- Сукно
    --------------------------------------------------

    renderer.panel(

        1,

        1,

        width,

        height,

        tableView.colors.felt

    )



    --------------------------------------------------
    -- Рамка
    --------------------------------------------------

    renderer.border(

        2,

        2,

        width - 2,

        height - 2,

        tableView.colors.border

    )



    --------------------------------------------------
    -- Дилер
    --------------------------------------------------

    renderer.text(

        4,

        3,

        "DEALER",

        tableView.colors.text

    )



    --------------------------------------------------
    -- Игрок
    --------------------------------------------------

    renderer.text(

        4,

        math.max(

            8,

            height - 10

        ),

        "PLAYER",

        tableView.colors.text

    )



    --------------------------------------------------
    -- Ставка
    --------------------------------------------------

    renderer.text(

        math.floor(width / 2) - 2,

        height - 5,

        "BET",

        tableView.colors.line

    )


end

--------------------------------------------------

return tableView