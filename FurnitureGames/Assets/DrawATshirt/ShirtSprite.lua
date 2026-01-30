--!Type(Client)

local myPlayer = nil
local myMeshRenderer = nil

function self:ClientStart()
    myMeshRenderer = self.gameObject:GetComponent(MeshRenderer)
    myPlayer = self.transform.parent.parent.gameObject:GetComponent(Character).player
    print(typeof(myPlayer))
    myPlayer.character:AttachToBone(self.transform.parent, Bones.body)
    --Timer.After(0.2, function()
    --    self.transform.position = Vector3.new(.046, 0.19, -0.122)
    --    self.transform.rotation = Quaternion.Euler(-.429,-28.58,.11)
    --    self.transform.scale = Vector3.new(0.409,.499,.53)
    --    print("Set shirt transform")
    --end)
end

function self:ClientUpdate()
    if not myPlayer or not myPlayer.character then
        return
    end
    --313 135
    -- hide self if myplayer.character rot is not between 135 and 313
    local rotY = myPlayer.character.transform.rotation.eulerAngles.y
    if rotY > 313 or rotY < 135 then
        myMeshRenderer.enabled = false
    else
        myMeshRenderer.enabled = true
    end
end