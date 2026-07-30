--------------------------------------------------
-- BlackJack
-- game/dealer.lua
--------------------------------------------------

local cards = require("game.cards")

local dealer = {}

--------------------------------------------------
-- Создать дилера
--------------------------------------------------

function dealer.new()

    return {

        hand = {},

        standing = false,

        blackjack = false,

        bust = false

    }

end

--------------------------------------------------
-- Очистить
--------------------------------------------------

function dealer.reset(self)

    self.hand = {}

    self.standing = false

    self.blackjack = false

    self.bust = false

end

--------------------------------------------------
-- Взять карту
--------------------------------------------------

function dealer.hit(self, card)

    if not card then
        return
    end


    table.insert(

        self.hand,

        card

    )


    self.blackjack =
        cards.isBlackjack(self.hand)


    self.bust =
        cards.isBust(self.hand)

end

--------------------------------------------------
-- Очки
--------------------------------------------------

function dealer.points(self)

    return cards.getValue(self.hand)

end

--------------------------------------------------
-- Количество карт
--------------------------------------------------

function dealer.cardCount(self)

    return #self.hand

end

--------------------------------------------------
-- Последняя карта
--------------------------------------------------

function dealer.lastCard(self)

    return self.hand[#self.hand]

end

--------------------------------------------------
-- Открытая карта
--------------------------------------------------

function dealer.openCard(self)

    return self.hand[2]

end

--------------------------------------------------
-- Закрытая карта
--------------------------------------------------

function dealer.hiddenCard(self)

    return self.hand[1]

end

--------------------------------------------------
-- Видимая рука
--------------------------------------------------

function dealer.visibleHand(self)

    local result = {}

    for i = 2, #self.hand do

        table.insert(

            result,

            self.hand[i]

        )

    end

    return result

end

--------------------------------------------------
-- Стоять
--------------------------------------------------

function dealer.stand(self)

    self.standing = true

end

--------------------------------------------------
-- Ход дилера
--------------------------------------------------

function dealer.play(self, deck)

    while dealer.mustHit(self) do

        local card =
            deck.draw()

        if not card then
            break
        end

        dealer.hit(

            self,

            card

        )


    end


    dealer.stand(self)

end

--------------------------------------------------
-- Нужно ли брать
--------------------------------------------------

function dealer.mustHit(self)

    return

        dealer.points(self) < 17

        and

        not self.bust

end

--------------------------------------------------
-- Закончил ли ход
--------------------------------------------------

function dealer.isDone(self)

    return self.standing

end

--------------------------------------------------
-- Перебор
--------------------------------------------------

function dealer.isBust(self)

    return self.bust

end

--------------------------------------------------
-- Blackjack
--------------------------------------------------

function dealer.isBlackjack(self)

    return self.blackjack

end

--------------------------------------------------
-- Стоит
--------------------------------------------------

function dealer.isStanding(self)

    return self.standing

end

--------------------------------------------------

return dealer