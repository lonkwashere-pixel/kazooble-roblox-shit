-- Fit the visible standing Banjo mesh to a standard 5.5-stud Roblox body.
local Graphics=require(script.Parent.Graphics);local Animation=require(script.Parent.Animation)
local Config=require(script.Parent.Config)
local Settings=require(script.Parent.Settings)
local Sizing={};local ratio,footOffset
function Sizing.visualRatio(characterScale)
    characterScale=characterScale or Settings.Defaults.CharacterScale
    if ratio then return ratio*characterScale,footOffset*characterScale end
    local data=Graphics.data();local pose=Animation.pose(data,"idle",0)
    local low,high=math.huge,-math.huge
    for _,desc in data.character do
        local visible=true
        for _,s in desc.selectors do
            local choice=(s[1]==9 or s[1]==10 or s[1]==11) and 0 or 1
            if choice~=s[2]then visible=false;break end
        end
        if visible then
            local vertices=Graphics.read(desc,true)
            for _,v in vertices do
                local p=Vector3.zero
                for _,w in v.skin do p+=Animation.transform(pose[w.bone],w.position)*w.weight end
                if #v.skin==0 then p=v.position end
                low=math.min(low,p.Y*Config.Scale);high=math.max(high,p.Y*Config.Scale)
            end
        end
    end
    ratio=Config.AvatarHeight/(high-low)
    footOffset=-low*ratio
    return ratio*characterScale,footOffset*characterScale
end
return Sizing
