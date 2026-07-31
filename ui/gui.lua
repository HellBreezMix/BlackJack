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

gui.playerName = ""

gui.authorized = false

gui.sessionTime = 60

gui.timer = nil

gui.lastPlayer = nil


--------------------------------------------------
-- ADMIN
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
-- TIMER
--------------------------------------------------

function gui.stopTimer()


    if gui.timer then

        event.cancel(gui.timer)

        gui.timer = nil

    end


end




function gui.resetSession()


    gui.sessionTime = 60


end





function gui.startTimer()


    gui.stopTimer()


    gui.sessionTime = 60



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





function gui.touchActivity()


    if gui.authorized then

        gui.sessionTime = 60

    end


end





function gui.logout()


    gui.authorized = false

    gui.playerName = ""

    gui.sessionTime = 60


    gui.stopTimer()


    if gui.screen ~= "menu" then

        gui.screen = "menu"

    end


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



        local tx =

            b.x +
            math.floor(
                (
                    b.w -
                    unicode.len(b.text)
                )
                /2
            )



        renderer.text(

            tx,

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
            7,

            "СЕССИЯ:",

            theme.colors.text

        )



        renderer.text(

            x+12,
            7,

            tostring(gui.sessionTime),

            theme.colors.gold

        )



        gui.addButton(

            x+4,
            10,
            18,
            3,
            "ВЫХОД",

            function()

                gui.logout()

            end

        )



    else



        renderer.center(

            5,

            "НЕТ ВХОДА",

            theme.colors.text

        )


    end





    renderer.center(

        13,

        "ТОП 15 ИГРОКОВ",

        theme.colors.gold

    )



    local y = 15



    if #gui.topPlayers == 0 then



        renderer.center(

            y,

            "НЕТ ДАННЫХ",

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



    renderer.center(

        4,

        "АВТОРИЗАЦИЯ",

        theme.colors.gold

    )




    if gui.authorized then



        renderer.center(

            6,

            gui.playerName,

            theme.colors.text

        )


    else



        gui.addButton(

            10,
            8,
            20,
            3,
            "АВТОРИЗАЦИЯ",

            function()


                -- ручная кнопка

                -- имя берём из touch

            end

        )



    end





    gui.addButton(

        10,
        13,
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





    if gui.authorized and gui.admins[gui.playerName] then



        gui.addButton(

            10,
            18,
            20,
            3,
            "АДМИН-ПАНЕЛЬ",

            function()



                gui.screen="admin"


                gui.draw()



            end

        )



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



    renderer.center(

        4,

        gui.playerName,

        theme.colors.text

    )




    local state = controller.getState()



    if state then



        renderer.text(

            3,
            7,
            "ДИЛЕР:",

            theme.colors.text

        )



        cardRenderer.drawDealer(

            state.dealerCards,

            3,
            9

        )




        renderer.text(

            3,
            18,
            "ИГРОК:",

            theme.colors.text

        )



        cardRenderer.drawPlayer(

            state.playerCards,

            3,
            20

        )



        gui.addButton(

            4,
            30,
            12,
            3,
            "ВЗЯТЬ",

            function()

                controller.hit()

                gui.touchActivity()

                gui.draw()

            end

        )




        gui.addButton(

            18,
            30,
            12,
            3,
            "СТОП",

            function()

                controller.stand()

                gui.touchActivity()

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

        "СКУПКА ПРЕДМЕТОВ",

        theme.colors.text

    )




    gui.addButton(

        5,
        8,
        30,
        3,
        "ДОБАВИТЬ ПРЕДМЕТ",

        function()



            -- позже подключим

            -- сохранение в config



        end


    )




    gui.addButton(

        5,
        13,
        30,
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
-- MAIN DRAW
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
-- TOUCH HANDLER
--------------------------------------------------

function gui.touch(_,_,x,y)



    gui.touchActivity()



    if gui.checkButtons(x,y) then


        return


    end



end





--------------------------------------------------
-- LOGIN
--------------------------------------------------

function gui.login(name)



    if gui.authorized then

        return false

    end



    gui.authorized=true


    gui.playerName=name


    gui.startTimer()



    gui.draw()



    return true


end





--------------------------------------------------
-- INIT
--------------------------------------------------

function gui.init()



    event.listen(

        "touch",

        gui.touch

    )



    gui.draw()



end

--------------------------------------------------
-- START
--------------------------------------------------

function gui.start()

    gui.screen = "menu"

    gui.touchActivity()

    gui.draw()

end


return gui
