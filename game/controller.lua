--------------------------------------------------
-- BlackJack
-- game/controller.lua
--------------------------------------------------

local game = require("game.game")

local payout = require("game.payout")


local controller = {}


--------------------------------------------------
-- Текущий игрок
--------------------------------------------------

controller.playerName = "Player"



--------------------------------------------------
-- Начать игру
--------------------------------------------------

function controller.start(playerName)


    controller.playerName =
        playerName or "Player"



    game.new(

        controller.playerName

    )


    game.deal()


end



--------------------------------------------------
-- Взять карту
--------------------------------------------------

function controller.hit()


    if game.isFinished() then

        return

    end



    game.playerHit()


end



--------------------------------------------------
-- Остановиться
--------------------------------------------------

function controller.stand()


    if game.isFinished() then

        return

    end



    game.playerStand()


end



--------------------------------------------------
-- Удвоить ставку
--------------------------------------------------

function controller.double()


    if game.isFinished() then

        return

    end



    game.playerDouble()


end



--------------------------------------------------
-- Получить карты игрока
--------------------------------------------------

function controller.playerCards()


    return game.getPlayerHand()


end



--------------------------------------------------
-- Получить карты дилера
--------------------------------------------------

function controller.dealerCards()


    return game.getDealerHand()


end



--------------------------------------------------
-- Очки игрока
--------------------------------------------------

function controller.playerPoints()


    return game.getPlayerPoints()


end



--------------------------------------------------
-- Очки дилера
--------------------------------------------------

function controller.dealerPoints()


    return game.getDealerPoints()


end



--------------------------------------------------
-- Проверка окончания
--------------------------------------------------

function controller.finished()


    return game.isFinished()


end



--------------------------------------------------
-- Результат
--------------------------------------------------

function controller.result()


    local result =
        game.getResult()



    if result == nil then

        return "PLAYING"

    end



    return result


end



--------------------------------------------------
-- Выплата
--------------------------------------------------

function controller.calculateWin(bet)


    return payout.calculate(

        bet,

        game.getResult()

    )


end



--------------------------------------------------
-- Объект игры
--------------------------------------------------

function controller.getGame()


    return game


end



--------------------------------------------------

return controller