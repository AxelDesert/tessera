math.randomseed(os.time())

function RollDice(amount)
    local dice = {}
    for i = 1, amount do
        table.insert(dice, math.random(1, 6))
    end
    return dice
end

function SixDiceCheck(frequencyMap)
    local pairCounter = 0
    local tripleCounter = 0
    local straightCounter = 0
    local hasFourOfAKind = false
    for idx, value in ipairs(frequencyMap) do
        if value == 6 then return 3000 end
        if value == 4 then hasFourOfAKind = true end
        if value == 2 then pairCounter = pairCounter + 1 end
        if value == 3 then tripleCounter = tripleCounter + 1 end
        if value == 1 then straightCounter = straightCounter + 1 end
    end

    if pairCounter == 3 then return 1500 end
    if tripleCounter == 2 then return 2500 end
    if straightCounter == 6 then return 1500 end
    if hasFourOfAKind and pairCounter == 1 then return 1500 end
    return 0
end

function DiceCheck(frequencyMap)
    local score = 0
    if (frequencyMap[1] >= 1 or frequencyMap[6] >= 1) 
    and frequencyMap[2] >= 1
    and frequencyMap[3] >= 1
    and frequencyMap[4] >= 1
    and frequencyMap[5] >= 1 then 
    
        score = score + 750 
        
        frequencyMap[2] = frequencyMap[2] - 1
        frequencyMap[3] = frequencyMap[3] - 1
        frequencyMap[4] = frequencyMap[4] - 1
        frequencyMap[5] = frequencyMap[5] - 1
        if frequencyMap[1] >= 1 then
            frequencyMap[1] = frequencyMap[1] - 1
        else
            frequencyMap[6] = frequencyMap[6] - 1
        end
    end
    for idx, value in ipairs(frequencyMap) do
        if value == 5 then 
            score = score + 2000
            frequencyMap[idx] = 0
        elseif value == 4 then 
            score = score + 1000
            frequencyMap[idx] = 0
            
        elseif value == 3 then
            if idx == 1 then
                score = score + 1000
            else
                score = score + (idx * 100)
            end
            frequencyMap[idx] = 0
        end
    end
    score = score + (frequencyMap[1] * 100)
    score = score + (frequencyMap[5] * 50)

    return score
end

function CalculateScore(dice, selection)
    local diceSelection = {}
    local frequencyMap = {0, 0, 0, 0, 0, 0}
    for _, i in ipairs(selection) do
        table.insert(diceSelection, dice[i])
    end
    for _, face in ipairs(diceSelection) do
        frequencyMap[face] = frequencyMap[face] + 1
    end
    local score = SixDiceCheck(frequencyMap)

    if (score == 0) then
        return DiceCheck(frequencyMap)
    else
        return score
    end
end

function PrintRoll(hand)
    print("You rolled: ")
    print("---------------------------")
    print("|  " .. table.concat(hand, "   ") .. "  |")
    print("---------------------------\n")
end

function CheckFarkle(hand)
    local handScore = CalculateScore(hand, {1, 2, 3, 4, 5, 6})

    if handScore == 0 then
        print("FARKLEEEEE !!!!!!!")
    end
    return handScore
end

function Round()
    local hand = {}
    local roundScore = 0
    local roundEnded = false
    local farkled = false
    local handScore = 0
    local remainingDice = 6

    while not roundEnded do 
        hand = RollDice(remainingDice)
        PrintRoll(hand)
        if CheckFarkle(hand) == 0 then
            farkled = true
            roundEnded = true
            break
        end
        io.write("Your selection : ")
        local userInput = io.read()
        local selection = {}
        for w in userInput:gmatch("%w+") do table.insert(selection, tonumber(w)) end
        remainingDice = remainingDice - #selection
        handScore = CalculateScore(hand, selection)
        roundScore = roundScore + handScore
        if remainingDice == 0 then
            print("HOT DICE! You get 6 fresh dice to keep rolling!")
            remainingDice = 6
        end
        print("You scored " .. roundScore .. " points.")
        io.write("If you want to bank type X, if you want to re-roll type O : ")
        userInput = io.read()
        if userInput == "X" then
            roundEnded = true
        end
    end

    if farkled then
        return 0
    else
        print("You have banked " .. roundScore .. ". Good job !")
        return roundScore
    end
end

function Play()
    local gameEnded = false
    local bank = 0

    print("Let's play farkle my friend !\n")
    while not gameEnded do
        bank = bank + Round()
        print("TOTAL BANK: " .. bank)
        
        if bank >= 10000 then
            print("YOU WON !!!! GGEZ")
            gameEnded = true
        end
    end
end

Play()