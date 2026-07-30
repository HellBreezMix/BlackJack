--------------------------------------------------
-- BlackJack
-- game/game.lua
--------------------------------------------------

local deck = require("game.deck")

local player = require("game.player")

local dealer = require("game.dealer")


local game = {}


--------------------------------------------------
-- Состояние
--------------------------------------------------

game.player = nil

game.dealer = nil

game.finished = false

game.result = nil


--------------------------------------------------
-- Новая игра
--------------------------------------------------

function game.new(name, deckCount)


    deck.new(
        deckCount or 1
    )


    game.player =
        player.new(name)


    game.dealer =
        dealer.new()


    game.finished = false

    game.result = nil


end



--------------------------------------------------
-- Раздача
--------------------------------------------------

function game.deal()


    game.player:hit(
        deck.draw()
    )


    game.dealer:hit(
        deck.draw()
    )


    game.player:hit(
        deck.draw()
    )


    game.dealer:hit(
        deck.draw()
    )


    game.checkInitial()


end



--------------------------------------------------
-- Начальная проверка
--------------------------------------------------

function game.checkInitial()


    if game.player:isBlackjack() then

        game.finish(
            "BLACKJACK"
        )

        return

    end



    if game.dealer:isBlackjack() then

        game.finish(
            "LOSE"
        )

        return

    end


end



--------------------------------------------------
-- HIT
--------------------------------------------------

function game.playerHit()


    if game.finished then

        return

    end



    local card =
        deck.draw()


    if card then

        game.player:hit(card)

    end



    game.check()


end



--------------------------------------------------
-- STAND
--------------------------------------------------

function game.playerStand()


    if game.finished then

        return

    end


    game.player:stand()


    game.dealerTurn()


end



--------------------------------------------------
-- DOUBLE
--------------------------------------------------

function game.playerDouble()

    return false

end



--------------------------------------------------
-- Ход дилера
--------------------------------------------------

function game.dealerTurn()


    while game.dealer:mustHit() do


        local card =
            deck.draw()


        if card then

            game.dealer:hit(card)

        else

            break

        end


    end



    game.dealer:stand()


    game.check()


end



--------------------------------------------------
-- Проверка
--------------------------------------------------

function game.check()


    if game.player:isBust() then

        game.finish("LOSE")

        return

    end



    if game.dealer:isBust() then

        game.finish("WIN")

        return

    end



    if game.player:isStanding() then

        game.compare()

    end


end



--------------------------------------------------
-- Сравнение
--------------------------------------------------

function game.compare()


    local p =
        game.player:points()


    local d =
        game.dealer:points()



    if p > d then

        game.finish("WIN")


    elseif p < d then

        game.finish("LOSE")


    else

        game.finish("DRAW")


    end


end



--------------------------------------------------
-- Завершение
--------------------------------------------------

function game.finish(result)


    game.finished = true

    game.result = result


end



--------------------------------------------------
-- Карты игрока
--------------------------------------------------

function game.getPlayerHand()

    return game.player.hand

end



--------------------------------------------------
-- Карты дилера
--------------------------------------------------

function game.getDealerHand()

    return game.dealer.hand

end



--------------------------------------------------
-- Очки игрока
--------------------------------------------------

function game.getPlayerPoints()

    return game.player:points()

end



--------------------------------------------------
-- Очки дилера
--------------------------------------------------

function game.getDealerPoints()


    if game.finished then

        return game.dealer:points()

    end


    return "?"

end



--------------------------------------------------
-- Состояние
--------------------------------------------------

function game.isFinished()

    return game.finished

end



--------------------------------------------------
-- Результат
--------------------------------------------------

function game.getResult()

    return game.result

end



--------------------------------------------------

return game