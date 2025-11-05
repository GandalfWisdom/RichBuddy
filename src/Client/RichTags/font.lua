--!strict
--[=[
    ITALIC implementation.
]=]
local TextService: TextService = game:GetService("TextService");
return {
    Letterwise = false; -- Whether letters are effected individually.
    ValidAttributes = {"color", "size", "face"}; -- Valid attributes for tag.
    Apply = function(label: TextLabel, attributes: {}): { RBXScriptConnection? }
        local color: Color3 = if (attributes["color"]) then Color3.fromHex(attributes["color"]) else label.TextColor3;
        local size: number? = if (attributes["size"]) then tonumber(attributes["size"]) else label.TextSize;
        local face: Enum.Font? = if (attributes["face"]) then Enum.Font:FromName(attributes["face"]) else label.Font;

        label.TextColor3 = color;
        label.TextSize = size :: number;
        label.Font = face :: Enum.Font;

        local frame: Frame = label.Parent :: Frame;
        local text_bounds: Vector2 = TextService:GetTextSize(label.Text, label.TextSize, label.Font, (Vector2.one * math.huge));

        frame.Size = UDim2.fromOffset(text_bounds.X, 0);
        (frame.Parent :: Frame).Size = UDim2.fromOffset(0, if (label.LayoutOrder == 0) then math.min(size :: number, 100) else math.min(math.max(size :: number, frame.AbsoluteSize.X), 100)) -- At most 100 because Roblox cannot render text larger than that
        return {};
    end;
};