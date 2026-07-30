--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- updated version
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
-- BUTTON SYSTEM
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

            x = x,

            y = y,

            w = w,

            h = h,

            text = text,

            callback = callback

        }

    )


end



--------------------------------------------------
-- DRAW BUTTONS
--------------------------------------------------

function gui.drawButtons()


    for _, b in ipairs(gui.buttons) do


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



        local textWidth =

            unicode.len(
                tostring(b.text)
            )



        local tx =

            b.x +

            math.floor(
                (b.w - textWidth) / 2
            )



        local ty =

            b.y +

            math.floor(
                (b.h + 1) / 2
            )



        renderer.text(

            tx,

            ty,

            b.text,

            theme.colors.text

        )


    end


end



--------------------------------------------------
-- CHECK BUTTONS
--------------------------------------------------

function gui.checkButtons(x,y)


    for _, b in ipairs(gui.buttons) do


        if

            x >= b.x

            and x <= b.x + b.w

            and y >= b.y

            and y <= b.y + b.h

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
-- MENU
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

        10,

        8,

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
-- GAME
--------------------------------------------------

function gui.drawGame()


    renderer.clear()


    gui.clearButtons()



    renderer.center(

        2,

        "BLACKJACK TABLE",

        theme.colors.gold

    )




    renderer.text(

        3,

        4,

        "DEALER:",

        theme.colors.text

    )



    renderer.text(

        12,

        4,

        tostring(
            controller.dealerPoints()
        ),

        theme.colors.gold

    )




    cardRenderer.drawDealer(

        controller.dealerCards(),

        3,

        6,

        not controller.finished()

    )
        cardRenderer.drawDealer(

        controller.dealerCards(),

        3,

        6,

        not controller.finished()

    )





    renderer.text(

        3,

        15,

        "PLAYER:",

        theme.colors.text

    )



    renderer.text(

        12,

        15,

        tostring(
            controller.playerPoints()
        ),

        theme.colors.gold

    )




    cardRenderer.drawHand(

        controller.playerCards(),

        3,

        17

    )





    --------------------------------------------------
    -- RESULT / BUTTONS
    --------------------------------------------------

    if controller.finished() then


        renderer.center(

            22,

            "RESULT: "

            ..

            tostring(
                controller.result()
            ),

            theme.colors.gold

        )



        gui.addButton(

            12,

            25,

            18,

            3,

            "NEW GAME",


            function()


                controller.newGame()


                gui.draw()


            end


        )



    else



        gui.addButton(

            5,

            25,

            12,

            3,

            "HIT",


            function()


                controller.hit()


                gui.draw()


            end


        )



        gui.addButton(

            20,

            25,

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
-- DRAW
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
