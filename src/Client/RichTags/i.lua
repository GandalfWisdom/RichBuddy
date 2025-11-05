--!strict
--[=[
    ITALIC implementation.
]=]
return {
    Letterwise = false; -- Whether letters are effected individually.
    ValidAttributes = {}; -- Valid attributes for tag.
    Apply = function(label: TextLabel, attributes: {}): { RBXScriptConnection? }
        label.Text = "<i>"..label.Text.."</i>";
        return {};
    end;
};