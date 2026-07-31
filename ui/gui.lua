--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- main casino interface
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

gui.playerName = nil

gui.authorized = false

gui.isAdmin = false


-- таймер сессии

gui.sessionTime = 60

gui.timer = nil

gui.lastTouch = 0



--------------------------------------------------
-- ADMIN LIST
--------------------------------------------------

gui.admins = {

    ["hellbreez"] = true,

    ["Lofland"] = true

}



--------------------------------------------------
-- TOP PLAYERS
--------------------------------------------------

gui.topPlayers = {}




--------------------------------------------------
-- LANGUAGE
--------------------------------------------------

local lang = {

    title = "BLACKJACK",

    auth = "АВТОРИЗАЦИЯ",

    login = "АВТОРИЗАЦИЯ",

    logout = "ВЫХОД",

    play = "ИГРАТЬ",

    top = "ТОП 15 ИГРОКОВ",

    noData = "НЕТ ДАННЫХ",

    admin = "АДМИН-ПАНЕЛЬ",

    session = "СЕССИЯ",

    hit = "ВЗЯТЬ",

    stand = "СТОП"


}



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

            x>=b.x
            and x<=b.x+b.w

            and

            y>=b.y
            and y<=b.y+b.h


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
-- SESSION TIMER
--------------------------------------------------

function gui.resetTimer()


    gui.lastTouch = os.time()



    if gui.timer then

        event.cancel(gui.timer)

    end



    gui.timer = event.timer(

        gui.sessionTime,

        function()


            gui.logout()


        end

    )


end





function gui.logout()


    gui.authorized = false

    gui.isAdmin = false

    gui.playerName = nil



    gui.screen = "menu"



    if gui.timer then

        event.cancel(gui.timer)

        gui.timer = nil

    end



    gui.draw()


end





--------------------------------------------------
-- LOGIN
--------------------------------------------------

function gui.login(player)


    if not player then

        return

    end



    gui.authorized = true


    gui.playerName = player



    gui.isAdmin =
        gui.admins[player] == true



    gui.resetTimer()



    gui.draw()


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




    renderer.center(

        3,

        lang.auth,

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

            tostring(gui.playerName),

            theme.colors.gold

        )




        renderer.text(

            x+2,

            7,

            lang.session,

            theme.colors.text

        )



        renderer.text(

            x+11,

            7,

            "60",

            theme.colors.gold

        )



        gui.addButton(

            x+3,

            9,

            20,

            3,

            lang.logout,



            function()


                gui.logout()


            end

        )




        if gui.isAdmin then


            gui.addButton(

                x+3,

                13,

                20,

                3,

                lang.admin,


                function()


                    gui.screen =
                        "admin"


                    gui.draw()


                end

            )


        end



    else



        gui.addButton(

            x+3,

            5,

            20,

            3,

            lang.login,


            function()


                -- ждём touch игрока


            end

        )



    end





    renderer.center(

        19,

        lang.top,

        theme.colors.gold

    )




    if #gui.topPlayers == 0 then


        renderer.center(

            21,

            lang.noData,

            theme.colors.text

        )


    else


        local y = 21


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

        lang.title,

        theme.colors.gold

    )



    gui.addButton(

        10,

        8,

        20,

        3,

        lang.play,


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
-- GAME SCREEN
--------------------------------------------------

function gui.drawGame()


    renderer.clear()

    gui.clearButtons()



    renderer.center(

        2,

        lang.title,

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

            lang.hit,


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

            lang.stand,


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

        6,

        "ДОБАВЛЕНИЕ СКУПКИ",

        theme.colors.text

    )



    renderer.center(

        10,

        "Скоро: настройка предметов",

        theme.colors.text

    )



    renderer.center(

        12,

        "и стоимости в ЭМ",

        theme.colors.text

    )



    gui.addButton(

        10,

        20,

        20,

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
-- TOUCH
--------------------------------------------------

function gui.touch(

    x,

    y,

    player

)


    gui.resetTimer()



    if not gui.authorized then



        if player then


            gui.login(player)


        end



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
