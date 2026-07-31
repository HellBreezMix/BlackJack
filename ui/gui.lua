--------------------------------------------------
-- BlackJack
-- ui/gui.lua
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

gui.authorized = false

gui.playerName = ""

gui.sessionTime = 60

gui.timer = nil



--------------------------------------------------
-- ADMINS
--------------------------------------------------

gui.admins = {

    ["hellbreez"] = true,
    ["Lofland"] = true

}



--------------------------------------------------
-- TIMER
--------------------------------------------------

function gui.stopTimer()

    if gui.timer then

        event.cancel(gui.timer)

        gui.timer = nil

    end

end



function gui.resetTimer()

    gui.sessionTime = 60

end



function gui.startTimer()

    gui.stopTimer()


    gui.timer = event.timer(
        1,
        function()

            if gui.authorized then

                gui.sessionTime =
                    gui.sessionTime - 1


                if gui.sessionTime <= 0 then

                    gui.logout()

                end


                gui.draw()

            end

        end,
        math.huge
    )

end



function gui.logout()


    gui.authorized = false

    gui.playerName = ""

    gui.stopTimer()

    gui.screen = "menu"

    gui.draw()


end



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


        renderer.text(
            b.x +
            math.floor(
                (b.w -
                unicode.len(b.text))/2
            ),

            b.y+1,

            b.text,

            theme.colors.text
        )


    end

end



function gui.checkButtons(x,y)


    for _,b in ipairs(gui.buttons) do


        if x >= b.x
        and x <= b.x+b.w
        and y >= b.y
        and y <= b.y+b.h then


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
        width - 28



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



    if gui.authorized then


        renderer.text(
            x+2,
            4,
            "ИГРОК:",
            theme.colors.text
        )


        renderer.text(
            x+10,
            4,
            gui.playerName,
            theme.colors.gold
        )



        renderer.text(
            x+2,
            6,
            "ТАЙМЕР:",
            theme.colors.text
        )



        renderer.text(
            x+12,
            6,
            tostring(gui.sessionTime),
            theme.colors.gold
        )



        gui.addButton(
            x+3,
            8,
            20,
            3,
            "ВЫХОД",
            function()

                gui.logout()

            end
        )



    else


        renderer.center(
            5,
            "ОЖИДАНИЕ",
            theme.colors.text
        )


    end



    renderer.center(
        13,
        "ТОП ИГРОКИ",
        theme.colors.gold
    )


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



    if not gui.authorized then


        gui.addButton(
            10,
            8,
            20,
            3,
            "АВТОРИЗАЦИЯ",
            function()

                -- авторизация
                -- происходит через touch event

            end
        )



    else


        renderer.center(
            6,
            gui.playerName,
            theme.colors.text
        )



        gui.addButton(
            10,
            12,
            20,
            3,
            "ИГРАТЬ",
            function()



                controller.start(
                    gui.playerName
                )


                gui.screen =
                    "game"



                gui.draw()


            end
        )



        if gui.admins[gui.playerName] then


            gui.addButton(
                10,
                17,
                20,
                3,
                "АДМИН-ПАНЕЛЬ",
                function()

                    gui.screen =
                        "admin"


                    gui.draw()

                end
            )


        end



    end



    gui.drawButtons()

    gui.drawSidePanel()


end





--------------------------------------------------
-- GAME SCREEN
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
        5,
        "ДИЛЕР:",
        theme.colors.text
    )



    renderer.text(
        12,
        5,
        tostring(
            controller.dealerPoints()
        ),
        theme.colors.gold
    )



    cardRenderer.drawDealer(
        controller.dealerCards(),
        3,
        7,
        not controller.finished()
    )



    renderer.text(
        3,
        18,
        "ИГРОК:",
        theme.colors.text
    )



    renderer.text(
        12,
        18,
        tostring(
            controller.playerPoints()
        ),
        theme.colors.gold
    )



    cardRenderer.drawHand(
        controller.playerCards(),
        3,
        20
    )



    if controller.finished() then


        renderer.center(
            27,
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
            "НОВАЯ",
            function()


                controller.newGame()

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

                gui.resetTimer()

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

                gui.resetTimer()

                gui.draw()

            end
        )



    end



    gui.drawButtons()

    gui.drawSidePanel()


end
--------------------------------------------------
-- ADMIN PANEL
--------------------------------------------------

function gui.drawAdmin()


    renderer.clear()


    gui.clearButtons()



    renderer.center(
        2,
        "АДМИН-ПАНЕЛЬ",
        theme.colors.gold
    )



    renderer.center(
        5,
        "УПРАВЛЕНИЕ СТАВКАМИ",
        theme.colors.text
    )



    gui.addButton(
        5,
        8,
        28,
        3,
        "ДОБАВИТЬ ПРЕДМЕТ",
        function()

            -- сюда подключим:
            -- data/items.lua
            -- стоимость в ЭМ

        end
    )



    gui.addButton(
        5,
        13,
        28,
        3,
        "НАЗАД",
        function()

            gui.screen="menu"

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



    elseif gui.screen=="admin" then


        gui.drawAdmin()



    end


end





--------------------------------------------------
-- LOGIN
--------------------------------------------------

function gui.login(player)


    if gui.authorized then

        return false

    end



    gui.authorized = true


    gui.playerName =
        player or "Guest"



    gui.resetTimer()


    gui.startTimer()



    gui.draw()



    return true


end





--------------------------------------------------
-- TOUCH
--------------------------------------------------

function gui.touch(
    x,
    y,
    player
)



    if gui.authorized then


        gui.resetTimer()



    else



        if player then


            gui.login(player)


            return


        end


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
