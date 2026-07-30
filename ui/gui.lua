--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- improved table layout
--------------------------------------------------

local event = require("event")
local unicode = require("unicode")

local renderer = require("ui.renderer")
local theme = require("ui.theme")

local controller = require("game.controller")
local cardRenderer = require("ui.card_renderer")


local gui = {}


--------------------------------------------------
-- STATE
--------------------------------------------------

gui.screen = "menu"

gui.buttons = {}

gui.playerName = "Player"



--------------------------------------------------
-- BUTTONS
--------------------------------------------------

function gui.clearButtons()

    gui.buttons = {}

end



function gui.addButton(
    x,
    y,
    w,
    h,
    text,
    callback
)

    table.insert(

        gui.buttons,

        {
            x=x,
            y=y,
            w=w,
            h=h,
            text=text,
            callback=callback
        }

    )

end



function gui.drawButtons()


    for _,b in ipairs(gui.buttons) do


        renderer.panel(

            b.x,
            b.y,
            b.w,
            b.h,
            0x3A3A3A

        )


        renderer.border(

            b.x,
            b.y,
            b.w,
            b.h,
            theme.colors.gold

        )


        local tx =
            b.x +
            math.floor(
                (b.w - unicode.len(b.text))
                / 2
            )


        local ty =
            b.y +
            math.floor(
                b.h / 2
            )


        renderer.text(

            tx,
            ty,
            b.text,
            theme.colors.text

        )


    end


end



function gui.checkButtons(x,y)


    for _,b in ipairs(gui.buttons) do


        if

            x >= b.x
            and x <= b.x+b.w
            and y >= b.y
            and y <= b.y+b.h

        then


            if b.callback then

                b.callback()

            end


            return true

        end


    end


    return false


end



--------------------------------------------------
-- DRAW MENU
--------------------------------------------------

function gui.drawMenu()


    renderer.clear()


    gui.clearButtons()



    renderer.center(

        2,
        "BLACKJACK",
        theme.colors.gold

    )


    renderer.center(

        4,
        "OpenComputers Casino",
        theme.colors.text

    )



    gui.addButton(

        30,
        10,
        20,
        3,
        "PLAY",


        function()


            controller.start(

                gui.playerName

            )


            gui.screen = "game"


            gui.draw()


        end

    )


    gui.drawButtons()


end



--------------------------------------------------
-- CARD ROW DRAW
--------------------------------------------------

function gui.drawCards(
    hand,
    startY
)


    local screenWidth =
        renderer.getResolution()


    local cardWidth =
        cardRenderer.width + 1


    local maxCards =
        math.floor(
            screenWidth / cardWidth
        )


    local x =
        3


    local y =
        startY



    local count = 0



    for _,card in ipairs(hand) do


        if count >= maxCards then


            count = 0

            x = 3

            y = y + cardRenderer.height + 2


        end



        cardRenderer.draw(

            x,
            y,
            card.rank,
            card.suit

        )


        x =
            x + cardWidth


        count = count + 1


    end


end



--------------------------------------------------
-- DEALER CARDS
--------------------------------------------------

function gui.drawDealerCards()


    cardRenderer.drawDealer(

        controller.dealerCards(),

        3,

        5,

        not controller.finished()

    )


end



--------------------------------------------------
-- PLAYER CARDS
--------------------------------------------------

function gui.drawPlayerCards()


    gui.drawCards(

        controller.playerCards(),

        17

    )


end
--------------------------------------------------
-- GAME SCREEN
--------------------------------------------------

function gui.drawGame()


    renderer.clear()


    gui.clearButtons()



    renderer.center(

        2,

        "BLACKJACK TABLE",

        theme.colors.gold

    )



    --------------------------------------------------
    -- DEALER
    --------------------------------------------------

    renderer.center(

        4,

        "DEALER: "
        ..
        tostring(
            controller.dealerPoints()
        ),

        theme.colors.text

    )



    gui.drawDealerCards()



    --------------------------------------------------
    -- PLAYER
    --------------------------------------------------

    renderer.center(

        15,

        "PLAYER: "
        ..
        tostring(
            controller.playerPoints()
        ),

        theme.colors.text

    )



    gui.drawPlayerCards()




    --------------------------------------------------
    -- RESULT
    --------------------------------------------------

    if controller.finished() then


        renderer.center(

            25,

            "RESULT: "
            ..
            tostring(
                controller.result()
            ),

            theme.colors.gold

        )



        gui.addButton(

            18,

            27,

            16,

            3,

            "NEW GAME",


            function()


                controller.newGame()


                gui.draw()


            end

        )



        gui.addButton(

            38,

            27,

            12,

            3,

            "MENU",


            function()


                gui.screen = "menu"


                gui.draw()


            end

        )



    else



        --------------------------------------------------
        -- GAME BUTTONS
        --------------------------------------------------


        gui.addButton(

            10,

            27,

            12,

            3,

            "HIT",


            function()


                controller.hit()


                gui.draw()


            end

        )



        gui.addButton(

            26,

            27,

            12,

            3,

            "STAND",


            function()


                controller.stand()


                gui.draw()


            end

        )


    end



    gui.drawButtons()


end





--------------------------------------------------
-- MAIN DRAW
--------------------------------------------------

function gui.draw()


    if gui.screen == "menu" then


        gui.drawMenu()


    elseif gui.screen == "game" then


        gui.drawGame()


    end


end





--------------------------------------------------
-- TOUCH
--------------------------------------------------

function gui.touch(x,y)


    gui.checkButtons(

        x,

        y

    )


end





--------------------------------------------------
-- START
--------------------------------------------------

function gui.start()


    gui.draw()



    while true do


        local _, _, x, y =

            event.pull(

                "touch"

            )



        if x and y then


            gui.touch(

                x,

                y

            )


        end


    end


end





--------------------------------------------------

return gui
