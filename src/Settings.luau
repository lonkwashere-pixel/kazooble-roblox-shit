-- Defaults overridden by options at the top of the Banjo LocalScript.
local Config=require(script.Parent.Config)
local Settings={}
Settings.Defaults=table.freeze({CharacterScale=.9,EnableStairs=true,EnableClimbing=true,EnablePads=true})
function Settings.normalize(requested)
    local result=table.clone(Settings.Defaults)
    if type(requested)=="table"then
        local scale=requested.CharacterScale
        if type(scale)=="number"and scale==scale then result.CharacterScale=math.clamp(scale,.5,1.5)end
        for _,key in {"EnableStairs","EnableClimbing","EnablePads"}do
            if type(requested[key])=="boolean"then result[key]=requested[key]end
        end
    end
    return result
end
function Settings.bodySize(options)return Config.BodySize*options.CharacterScale end
return Settings
