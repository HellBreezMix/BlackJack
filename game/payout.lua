--------------------------------------------------
-- BlackJack
-- game/payout.lua
--------------------------------------------------

local payout = {}

--------------------------------------------------
-- Коэффициенты
--------------------------------------------------

payout.multiplier = {

    WIN = 2.0,

    BLACKJACK = 2.5,

    DRAW = 1.0,

    LOSE = 0.0

}

--------------------------------------------------
-- Получить коэффициент
--------------------------------------------------

function payout.getMultiplier(result)

    return payout.multiplier[result] or 0

end


--------------------------------------------------
-- Рассчитать выплату
--------------------------------------------------

function payout.calculate(bet, result)


    bet =
        tonumber(bet) or 0


    local multiplier =
        payout.getMultiplier(result)


    return math.floor(

        bet * multiplier + 0.5

    )

end


--------------------------------------------------
-- Победа
--------------------------------------------------

function payout.isWinner(result)

    return result == "WIN"
        or result == "BLACKJACK"

end


--------------------------------------------------
-- Ничья
--------------------------------------------------

function payout.isDraw(result)

    return result == "DRAW"

end


--------------------------------------------------
-- Проигрыш
--------------------------------------------------

function payout.isLose(result)

    return result == "LOSE"

end


--------------------------------------------------
-- Текст
--------------------------------------------------

function payout.getText(result)


    if result == "WIN" then

        return "YOU WIN"

    end


    if result == "LOSE" then

        return "YOU LOSE"

    end


    if result == "DRAW" then

        return "DRAW"

    end


    if result == "BLACKJACK" then

        return "BLACKJACK!"

    end


    return "UNKNOWN"

end


--------------------------------------------------
-- Цвет
--------------------------------------------------

function payout.getColor(result)


    if result == "WIN" then

        return 0x00CC66

    end


    if result == "BLACKJACK" then

        return 0xFFD700

    end


    if result == "DRAW" then

        return 0xFFCC00

    end


    return 0xCC3333

end


--------------------------------------------------

return payout