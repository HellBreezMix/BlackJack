--------------------------------------------------
-- BlackJack
-- bank/economy.lua
--------------------------------------------------

local storage = require("lib.storage")
local config = require("config")

local economy = {}

--------------------------------------------------
-- Текущие ставки игроков
--------------------------------------------------

economy.bets = {}

--------------------------------------------------
-- Загрузить ставки
--------------------------------------------------

function economy.load()

    local data = storage.load(
        config.paths.bets
    )

    if data then

        economy.bets = data

    else

        economy.bets = {}

    end

end

--------------------------------------------------
-- Сохранить ставки
--------------------------------------------------

function economy.save()

    storage.save(
        config.paths.bets,
        economy.bets
    )

end

--------------------------------------------------
-- Создать ставку
--------------------------------------------------

function economy.createBet(player, item, count)

    if not player then
        return false
    end


    if not item then
        return false
    end


    count = tonumber(count) or 0


    if count <= 0 then
        return false
    end


    economy.bets[player] = {

        item = item,

        count = count,

        time = os.time()

    }


    economy.save()


    return true

end

--------------------------------------------------
-- Получить ставку игрока
--------------------------------------------------

function economy.getBet(player)

    return economy.bets[player]

end

--------------------------------------------------
-- Удалить ставку
--------------------------------------------------

function economy.removeBet(player)

    economy.bets[player] = nil

    economy.save()

end

--------------------------------------------------
-- Проверка ставки
--------------------------------------------------

function economy.hasBet(player)

    return economy.bets[player] ~= nil

end

--------------------------------------------------
-- Расчёт выигрыша
--------------------------------------------------

function economy.calculateWin(player, multiplier)

    local bet = economy.getBet(player)


    if not bet then
        return nil
    end


    return {

        item = bet.item,

        count = math.floor(
            bet.count * multiplier
        )

    }

end

--------------------------------------------------
-- Максимальная ставка
--------------------------------------------------

function economy.checkLimit(count)

    local max = config.game.maxBet


    if count > max then

        return false

    end


    return true

end

--------------------------------------------------

return economy