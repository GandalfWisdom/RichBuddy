local RichTags = {};

for _, module in pairs(script:GetChildren()) do
    if not (module:IsA("ModuleScript")) then continue; end;
    RichTags[module.Name] = require(module);
end;

return RichTags;