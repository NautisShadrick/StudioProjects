--!Type(UI)

--!Bind
local score_left_label : Label = nil
--!Bind
local score_right_label : Label = nil

function SetScores(scores)
    local leftScore = scores.left
    local rightScore = scores.right

    score_left_label.text = leftScore
    score_right_label.text = rightScore
end