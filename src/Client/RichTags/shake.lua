--!strict
--[=[
    SHAKE implementation.
]=]
local RunService: RunService = game:GetService("RunService");
return {
    Letterwise = true; -- Whether letters are effected individually.
    ValidAttributes = {"xmag", "ymag"}; -- Valid attributes for tag.
    Apply = function(label: TextLabel, attributes: {}): { RBXScriptConnection? }
        local xmag: number = if (attributes["xmag"]) then tonumber(attributes["xmag"]) :: number else 1;
        local ymag: number = if (attributes["ymag"]) then tonumber(attributes["ymag"]) :: number else 1;
        
        local time_elapsed = 0;
        local shake_interval = 0.05;
        local connection: RBXScriptConnection = RunService.Heartbeat:Connect(function(delta_time: number)
            if (time_elapsed < shake_interval) then
                time_elapsed += delta_time;
                return;
            end;
            time_elapsed = 0;
            label.Position = UDim2.fromOffset(
                math.round((math.random() - 0.5) * 2) * xmag,
                math.round((math.random() - 0.5) * 2) * ymag
            );
        end);
        return {connection};
    end;
};