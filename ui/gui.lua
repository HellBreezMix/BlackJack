--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- russian casino interface
--------------------------------------------------

local event = require("event")
local unicode = require("unicode")

local renderer = require("ui.renderer")
local theme = require("ui.theme")

local controller = require("game.controller")
local cardRenderer = require("ui.card_renderer")

local lang = require("lang.ru")


local gui = {}



--------------------------------------------------
-- STATE
--------------------------------------------------

gui.screen = "menu"

gui.buttons = {}

gui.playerName = "Guest"

gui.authorized = false


gui.timeout = 60

gui.timer = nil



--------------------------------------------------
-- TOP PLAYERS
--------------------------------------------------

-- позже подключим серверную статистику

gui.topPlayers = {}



--------------------------------------------------
-- SESSION TIMER
--------------------------------------------------

function gui.resetTimer()


    if gui.timer then

        event.cancel(gui.timer)

    end



    gui.timer = event.timer(

        gui.timeout,

        function()


            gui.authorized = false

            gui.playerName = "Guest"

            gui.screen = "menu"

            gui.draw()


        end

    )


end



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



        renderer.text(

            b.x +

            math.floor(
                (b.w -
                unicode.len(b.text))
                /2
            ),

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
-- SIDE PANEL
--------------------------------------------------

function gui.drawSidePanel()


    local width = renderer.getResolution()

    local x = width - 28



    renderer.panel(

        x,
        1,

        26,
        35,

        0x101010

    )



    renderer.border(

        x,
        1,

        26,
        35,

        theme.colors.gold

    )



    renderer.center(

        3,

        lang.AUTHORIZATION,

        theme.colors.gold

    )



    if gui.authorized then


        renderer.text(

            x+2,
            5,

            lang.PLAYER,

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

            lang.NO_LOGIN,

            theme.colors.text

        )


    end




    renderer.center(

        9,

        lang.TOP_PLAYERS,

        theme.colors.gold

    )



    local y = 11



    if #gui.topPlayers == 0 then


        renderer.center(

            y,

            lang.NO_DATA,

            theme.colors.text

        )


    else



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

                x+17,

                y,

                tostring(p.money),

                theme.colors.gold

            )



            y=y+1


        end


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



    gui.addButton(

        8,
        8,
        18,
        3,

        lang.PLAY,


        function()


            if not gui.authorized then

                return

            end



            controller.start(

                gui.playerName

            )


            gui.screen="game"


            gui.resetTimer()


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

        "BLACKJACK",

        theme.colors.gold

    )



    renderer.text(

        3,
        4,

        lang.DEALER,

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




    renderer.text(

        3,
        16,

        lang.PLAYER,

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





    if controller.finished() then



        renderer.center(

            26,

            lang.RESULT ..
            controller.result(),

            theme.colors.gold

        )




        gui.addButton(

            5,
            30,

            14,
            3,

            lang.NEW_GAME,


            function()


                controller.start(

                    gui.playerName

                )


                gui.resetTimer()

                gui.draw()


            end


        )




        gui.addButton(

            22,
            30,

            14,
            3,

            lang.MENU,


            function()


                gui.screen="menu"

                gui.resetTimer()

                gui.draw()


            end


        )




    else



        gui.addButton(

            5,
            30,

            12,
            3,

            lang.HIT,


            function()


                controller.hit()

                gui.resetTimer()

                gui.draw()


            end


        )




        gui.addButton(

            20,
            30,

            12,
            3,

            lang.STAND,


            function()


                controller.stand()

                gui.resetTimer()

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

function gui.touch(
    x,
    y,
    player
)



    gui.resetTimer()



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



        local e,_,x,y,button,player =

            event.pull()



        if e=="touch" then



            gui.touch(

                x,

                y,

                player

            )


        end



    end



end





return gui
