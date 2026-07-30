--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- russian interface
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

gui.playerName = "Гость"

gui.authorized = false


--------------------------------------------------
-- SESSION TIMER
--------------------------------------------------

gui.timeout = 60

gui.lastActivity = event.uptime()



--------------------------------------------------
-- TOP PLAYERS
--------------------------------------------------

gui.topPlayers = {}



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
            b.x + math.floor(
                (b.w-unicode.len(b.text))/2
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


    local width =
        renderer.getResolution()


    local x =
        width-28



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
        "АВТОРИЗАЦИЯ",
        theme.colors.gold
    )



    if gui.authorized then


        renderer.text(
            x+2,
            5,
            "ИГРОК:",
            theme.colors.text
        )


        renderer.text(
            x+10,
            5,
            gui.playerName,
            theme.colors.gold
        )


        renderer.text(
            x+2,
            7,
            "СЕССИЯ:",
            theme.colors.text
        )


        renderer.text(
            x+10,
            7,
            tostring(
                math.floor(
                    gui.timeout -
                    (event.uptime()-gui.lastActivity)
                )
            ),
            theme.colors.gold
        )


    else


        renderer.center(
            5,
            "НЕТ ВХОДА",
            theme.colors.text
        )


    end




    renderer.center(
        10,
        "ТОП 15 ИГРОКОВ",
        theme.colors.gold
    )



    if #gui.topPlayers == 0 then


        renderer.center(
            12,
            "НЕТ ДАННЫХ",
            theme.colors.text
        )


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
        10,
        8,
        20,
        3,
        "ИГРАТЬ",

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
        "ДИЛЕР:",
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
        "ИГРОК:",
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
            "РЕЗУЛЬТАТ: "
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
            "НОВАЯ ИГРА",

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
            "МЕНЮ",

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
            "ВЗЯТЬ",

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
            "СТОП",

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



    gui.lastActivity =
        event.uptime()



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



        local now =
            event.uptime()



        if

            gui.authorized
            and
            now-gui.lastActivity
            > gui.timeout

        then


            gui.authorized=false

            gui.playerName="Гость"

            gui.screen="menu"

            gui.draw()


        end




        local e =
            {event.pull(1)}



        if e[1]=="touch" then


            gui.touch(
                e[3],
                e[4],
                e[6]
            )


        end


    end


end



return gui
