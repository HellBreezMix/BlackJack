--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- simplified working version
--------------------------------------------------

local event = require("event")

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



function gui.addButton(x,y,w,h,text,callback)

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


        renderer.border(
            b.x,
            b.y,
            b.w,
            b.h,
            theme.colors.gold
        )


        renderer.center(
            b.y + 1,
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

        8,
        8,
        20,
        3,
        "PLAY",

        function()


            controller.start(
                gui.playerName
            )


            gui.screen="game"


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
        5,
        "PLAYER:"
    )


    renderer.text(
        12,
        5,
        tostring(
            controller.playerPoints()
        )
    )



    renderer.text(
        3,
        7,
        "DEALER:"
    )


    renderer.text(
        12,
        7,
        tostring(
            controller.dealerPoints()
        )
    )



    gui.addButton(
        5,
        18,
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
        18,
        12,
        3,
        "STAND",

        function()

            controller.stand()

            gui.draw()

        end
    )



    gui.drawButtons()



end



--------------------------------------------------
-- DRAW
--------------------------------------------------

function gui.draw()


    if gui.screen=="menu" then


        gui.drawMenu()


    elseif gui.screen=="game" then


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


        local _, address, x, y, button, player =
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



return gui
