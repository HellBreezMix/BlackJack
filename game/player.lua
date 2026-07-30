--------------------------------------------------
-- BlackJack
-- game/player.lua
--------------------------------------------------

local cards = require("game.cards")

local player = {}

player.__index = player


--------------------------------------------------
-- Создать игрока
--------------------------------------------------

function player.new(name)

    local self = setmetatable({}, player)


    self.name =
        name or "Player"


    self.hand = {}

    self.bet = 0

    self.standing = false

    self.blackjack = false

    self.bust = false

    self.doubled = false


    return self

end



--------------------------------------------------
-- Очистить
--------------------------------------------------

function player.reset(self)

    self.hand = {}

    self.bet = 0

    self.standing = false

    self.blackjack = false

    self.bust = false

    self.doubled = false

end



--------------------------------------------------
-- Взять карту
--------------------------------------------------

function player.hit(self, card)

    if not card then

        return false

    end


    table.insert(
        self.hand,
        card
    )


    self.blackjack =
        cards.isBlackjack(
            self.hand
        )


    self.bust =
        cards.isBust(
            self.hand
        )


    return true

end



--------------------------------------------------
-- Очки
--------------------------------------------------

function player.points(self)

    return cards.getValue(
        self.hand
    )

end



--------------------------------------------------
-- Количество карт
--------------------------------------------------

function player.cardCount(self)

    return #self.hand

end



--------------------------------------------------
-- Получить руку
--------------------------------------------------

function player.getHand(self)

    return self.hand

end



--------------------------------------------------
-- Последняя карта
--------------------------------------------------

function player.lastCard(self)

    return self.hand[#self.hand]

end



--------------------------------------------------
-- Стоять
--------------------------------------------------

function player.stand(self)

    self.standing = true

end



--------------------------------------------------
-- Можно брать карту
--------------------------------------------------

function player.canHit(self)

    return
        not self.standing
        and
        not self.bust

end



--------------------------------------------------
-- Разделение
--------------------------------------------------

function player.canSplit(self)

    if #self.hand ~= 2 then

        return false

    end


    return
        self.hand[1].rank ==
        self.hand[2].rank

end



--------------------------------------------------
-- Удвоение
--------------------------------------------------

function player.doubleBet(self)

    self.bet =
        self.bet * 2


    self.doubled = true

end



function player.isDoubled(self)

    return self.doubled

end



--------------------------------------------------
-- Проверки
--------------------------------------------------

function player.isStanding(self)

    return self.standing

end



function player.isBust(self)

    return self.bust

end



function player.isBlackjack(self)

    return self.blackjack

end



--------------------------------------------------
-- Ставка
--------------------------------------------------

function player.setBet(self, amount)

    self.bet =
        tonumber(amount) or 0

end



function player.getBet(self)

    return self.bet

end



--------------------------------------------------
-- Имя
--------------------------------------------------

function player.getName(self)

    return self.name

end



--------------------------------------------------

return player
