--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- casino interface version
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

gui.playerName = "Guest"

gui.authorized = false


--------------------------------------------------
-- SERVER TOP
--------------------------------------------------

gui.topPlayers = {

    {
        name="DankZell",
        money=117820
    },

    {
        name="Alibaba",
        money=21690
    },

    {
        name="Roman",
        money=15400
    },

    {
        name="Alex",
        money=9000
    },

    {
        name="Steve",
        money=7000
    }

}



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
            0x303030

        )


        renderer.border(

            b.x,
            b.y,
            b.w,
            b.h,
            theme.colors.gold

        )


        renderer.center(

            b.y+1,

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

            and

            y >= b.y
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
-- RIGHT PANEL
--------------------------------------------------


function gui.drawSidePanel()



    local x = 75



    renderer.panel(

        x,
        1,
        25,
        35,
        0x101010

    )



    renderer.border(

        x,
        1,
        25,
        35,
        theme.colors.gold

    )



    ------------------------------------------------
    -- AUTH
    ------------------------------------------------


    renderer.center(

        3,

        "AUTHORIZATION",

        theme.colors.gold

    )


    if gui.authorized then


        renderer.text(

            x+2,
            5,

            "PLAYER:",

            theme.colors.text

        )


        renderer.text(

            x+10,
            5,

            gui.playerName,

            theme.colors.gold

        )


    else


        renderer.center(

            5,

            "TOUCH TO LOGIN",

            theme.colors.text

        )


    end



    ------------------------------------------------
    -- TOP 15
    ------------------------------------------------


    renderer.center(

        9,

        "TOP 15 PLAYERS",

        theme.colors.gold

    )



    local y = 11



    for i,p in ipairs(gui.topPlayers) do


        if i > 15 then

            break

        end



        renderer.text(

            x+2,

            y,

            i.."."..p.name,

            theme.colors.text

        )


        renderer.text(

            x+16,

            y,

            tostring(p.money),

            theme.colors.gold

        )


        y = y + 1


    end


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


            if not gui.authorized then

                return

            end



            controller.start(

                gui.playerName

            )


            gui.screen="game"


            gui.draw()


        end


    )



    gui.addButton(

        10,

        13,

        20,

        3,

        "AUTH",

        function()

            gui.authorized=true

            gui.playerName="Player"

            gui.draw()

        end

    )



    gui.drawButtons()


    gui.drawSidePanel()


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



    ------------------------------------------------
    -- DEALER
    ------------------------------------------------


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




    ------------------------------------------------
    -- PLAYER
    ------------------------------------------------


    renderer.text(

        3,

        16,

        "PLAYER:",

        theme.colors.text

    )


    renderer.text(

        12,

        16,

        tostring(
            controller.playerPoints()
        ),

        theme.colors.gold

    )



    cardRenderer.drawHand(

        controller.playerCards(),

        3,

        18

    )





    ------------------------------------------------
    -- GAME BUTTONS
    ------------------------------------------------


    if controller.finished() then



        renderer.center(

            26,

            "RESULT: "
            ..
            tostring(
                controller.result()
            ),

            theme.colors.gold

        )



        gui.addButton(

            5,

            30,

            14,

            3,

            "NEW GAME",


            function()


                controller.start(

                    gui.playerName

                )


                gui.draw()


            end


        )




        gui.addButton(

            22,

            30,

            14,

            3,

            "MENU",


            function()


                gui.screen="menu"

                gui.draw()


            end


        )




    else



        gui.addButton(

            5,

            30,

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

            30,

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


    gui.drawSidePanel()



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

function gui.touch(x,y,player)



    ------------------------------------------------
    -- авторизация игрока
    ------------------------------------------------


    if not gui.authorized
    and player then


        gui.authorized=true


        gui.playerName=player


        gui.draw()


        return


    end





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



        local _,_,x,y,button,player =

            event.pull(
                "touch"
            )



        if x and y then


            gui.touch(

                x,

                y,

                player

            )


        end



    end



end





return gui
