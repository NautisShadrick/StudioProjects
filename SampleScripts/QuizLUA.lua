-- Lua Script: Element Quiz
-- Determines the player's element based on quiz answers

-- Define the base and specialized elements
elements = {
    "Fire", "Water", "Earth", "Air", -- Base elements
    "Metal", "Mist", "Lightning", "Sand", "Ice", "Life", -- Combination elements
    "Psychic", "Death" -- Specialized elements
}

-- Define the questions and answer choices
questions = {
    -- Each question has a set of answers, each tied to a specific element
    {
        question = "What environment appeals to you the most?",
        answers = {
            {text = "A warm, blazing desert", element = "Fire"},
            {text = "A serene lake", element = "Water"},
            {text = "A dense forest", element = "Earth"},
            {text = "A windy mountain peak", element = "Air"},
        }
    },
    {
        question = "What is your ideal weapon?",
        answers = {
            {text = "A flaming sword", element = "Fire"},
            {text = "A trident", element = "Water"},
            {text = "A sturdy hammer", element = "Metal"},
            {text = "A sharp dagger", element = "Lightning"},
        }
    },
    {
        question = "Which describes your personality best?",
        answers = {
            {text = "Passionate and bold", element = "Fire"},
            {text = "Calm and adaptable", element = "Water"},
            {text = "Grounded and steady", element = "Earth"},
            {text = "Free-spirited and curious", element = "Air"},
        }
    },
    {
        question = "What weather do you enjoy most?",
        answers = {
            {text = "Sunny and hot", element = "Fire"},
            {text = "Rainy and peaceful", element = "Mist"},
            {text = "Snowy and cold", element = "Ice"},
            {text = "Stormy and dramatic", element = "Lightning"},
        }
    },
    {
        question = "What motivates you the most?",
        answers = {
            {text = "The pursuit of knowledge", element = "Psychic"},
            {text = "A connection to nature", element = "Life"},
            {text = "The balance of power", element = "Death"},
            {text = "Creating something strong", element = "Metal"},
        }
    }
}

-- Define combinations of base elements
elementCombinations = {
    Metal = {"Fire", "Earth"}, -- Metal is a combination of Fire and Earth
    Mist = {"Water", "Air"}, -- Mist is a combination of Water and Air
    Lightning = {"Fire", "Air"}, -- Lightning is a combination of Fire and Air
    Sand = {"Earth", "Air"}, -- Sand is a combination of Earth and Air
    Ice = {"Water", "Earth"}, -- Ice is a combination of Water and Earth
    Life = {"Water", "Earth"}, -- Life is also a combination of Water and Earth
}

-- Initialize scores for each element
scores = {}
for _, element in ipairs(elements) do
    scores[element] = 0 -- Start each element's score at 0
end

-- Function to ask a question
function askQuestion(q)
    print(q.question) -- Display the question
    for i, answer in ipairs(q.answers) do
        print(i .. ". " .. answer.text) -- Display each answer with a number
    end
    
    local choice = 0
    repeat
        io.write("Choose an option (1-" .. #q.answers .. "): ")
        choice = tonumber(io.read()) -- Read the player's choice
    until choice >= 1 and choice <= #q.answers -- Ensure the choice is valid

    local selectedAnswer = q.answers[choice]
    scores[selectedAnswer.element] = scores[selectedAnswer.element] + 1 -- Add to the score of the selected element
end

-- Main quiz loop
print("Welcome to the Element Quiz! Answer the following questions to discover your element.\n")
for _, question in ipairs(questions) do
    askQuestion(question) -- Ask each question
    print("\n")
end

-- Combine scores for combination elements
for combo, bases in pairs(elementCombinations) do
    for _, base in ipairs(bases) do
        scores[combo] = (scores[combo] or 0) + scores[base] -- Add base scores to the combination element
    end
end

-- Determine the element with the highest score
local highestScore = 0
local playerElement = ""
for element, score in pairs(scores) do
    if score > highestScore then
        highestScore = score -- Update the highest score
        playerElement = element -- Update the element with the highest score
    end
end

-- Display the result
print("Your element is: " .. playerElement .. "!") -- Output the player's element
