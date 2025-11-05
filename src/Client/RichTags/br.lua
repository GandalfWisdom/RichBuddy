--!strict
--[=[
    BREAK implementation.
]=]
return {
    Letterwise = false; -- Whether letters are effected individually.
    ValidAttributes = {}; -- Valid attributes for tag.
    Apply = function(label: TextLabel, attributes: {}): { RBXScriptConnection? }
        local frame: Frame = Instance.new("Frame");
        frame.BackgroundTransparency = 1;
        frame.Size = UDim2.new(1, 0, 0, 0);
        frame.Name = "BreakLineFrame";
        frame.LayoutOrder = label.LayoutOrder + 1;
        task.spawn(function()
            repeat task.wait()
            until (label.Parent ~= nil);
            frame.Parent = label.Parent;
        end);
        print("breaking line!");
        return {};
    end;
};