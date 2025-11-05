--!strict
--[=[
    WRITE implementation. (typewriter effect).
]=]
local TS: TweenService = game:GetService("TweenService");
return {
    Letterwise = true; -- Whether letters are effected individually.
    ValidAttributes = {"speed", "style"}; -- Valid attributes for tag.
    Apply = function(label: TextLabel, attributes: {}): { RBXScriptConnection? }
        local speed: number = if (attributes["speed"]) then attributes["speed"] else 0;
        local style: string = if (attributes["style"]) then attributes["style"] else "Default";

        if (style ~= "Default") then
            if (style == "drop") then
                local tween = TS:Create(label, TweenInfo.new(0.2), {Position = label.Position, TextTransparency = 0;});
                label.Position = UDim2.fromOffset(label.Position.X.Offset, -label.TextSize * 2);
                label.TextTransparency = 1;
                tween:Play();
            elseif (style == "fade") then
                local tween = TS:Create(label, TweenInfo.new(0.8), {TextTransparency = 0;});
                label.TextTransparency = 1;
                tween:Play();
            end;
        end;

        if (speed ~= 0) then task.wait(speed) end;
        return {};
    end;
};