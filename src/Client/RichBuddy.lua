--!strict
local require = require(script.Parent.loader).load(script) :: any;
local TextService: TextService = game:GetService("TextService");
local Maid = require("Maid");
local RichFormat = require(script.Parent.RichFormat);
local StackBuddy = require("StackBuddy");

local RichDisplay = {};
RichDisplay.__index = RichDisplay;
RichDisplay.ClassName = "RichDisplay";

--Variables
local MAGIC_CHARACTERS: {string} = {"$", "%", "^", "*", "(", ")", ".", "[", "]", "+", "-", "?"};


export type Config = {
    WriteSpeed: number,
    WriteStyle: string,
};
--[=[
    Creates a new config table for RichDisplay
    @param config_table {[string]: any} -- A table of values to apply to config table.
    @return Config -- Configuration table for rich display.
]=]
local function new_config(config_table: {[string]: any}?): Config
    local config: Config = {
        WriteSpeed = 0;
        WriteStyle = "Default";
    };
    if not (config_table) then return config; end;
    for index, value in (config_table) do
        if not (config[index]) then continue; end; -- Check if given index is a valid config index.
        if not (typeof(value) == typeof(config[index])) then continue; end;
        config[index] = value;
    end;
    return config :: Config;
end;

export type RichDisplay = typeof(setmetatable(
    {} :: {
        _maid: Maid.Maid,
        _rich_text: RichFormat.RichFormat,
        _token_stack: StackBuddy.StackBuddy,
        _origin_label: TextLabel,
        _text_container: Folder,
        _config: Config,
        _list_layout: UIListLayout,
        _text_properties: {[string]: any},
        _text_index: number,
        _letterwise_count: number,
        _current_line_frame: Frame,
    },
    {} :: typeof({ __index = RichDisplay })
));

--[=[
    Constructs a new RichDisplay object.
    @param origin_label TextLabel -- The TextLabel the text will be inserted into as well as properties taken from.
    @param text string -- Text to be applies to RichDisplay
    @param config {[string]: any}? -- A table of configuration properties.
    @param text_properties {[string]: any}? -- A table of TextLabel properties to give to RichDisplay.
    @return RichDisplay
]=]
function RichDisplay.new(origin_label: TextLabel, text: string, config: {[string]: any}?, text_properties: {[string]: any}?): RichDisplay
    assert(origin_label, "Invalid text_container object!");
    local self: RichDisplay = setmetatable({} :: any, RichDisplay);
    self._maid = Maid.new();
    self._rich_text = self._maid:Add(RichFormat.new(text));
    self._token_stack = self._maid:Add(StackBuddy.new());
    self._origin_label = origin_label;
    self._text_properties = text_properties or self:_get_properties_from_label(origin_label);
    self._text_container = self._maid:Add(self:_create_text_container());
    self._config = new_config(config);
    self._list_layout = self:_create_list_layout(Enum.FillDirection.Vertical);
    self._text_index = 0;
    self._letterwise_count = 0;
    self:_create_line_frame(false);
    self:Init();
    return self;
end;


--[=[
    Populates container with richtext
]=]
function RichDisplay.Populate(self: RichDisplay): ()
    for token_index, token: RichFormat.RichToken | string in (self._rich_text:GetTokens()) do
        if (typeof(token) == "string") then -- Writes text
            self:_write_text(token);
        else
            if (token.Name == "br") then self:_create_line_frame(true); continue; end; -- Creates a new line if break token is found.
            if (token.IsOpening) then
                self._token_stack:Push(token);
                if (self._rich_text.Tags[token.Name].Letterwise) then 
                    self._letterwise_count += 1;
                end;
            else
                self._token_stack:Pop();
                if (self._rich_text.Tags[token.Name].Letterwise) then 
                    self._letterwise_count -= 1;
                end;
            end;
        end;
    end;
end;

--[=[
    Writes the text inside container.
    @param text string -- The text to be written.
]=]
function RichDisplay._write_text(self: RichDisplay, text: string): ()
    local font: Enum.Font = self._text_properties.Font;
    local text_size: number = self._text_properties.TextSize;
    for _, token: RichFormat.RichToken in (self._token_stack :: any) do -- Checks for custom font sizes and updates variable. Important for fit checking functions.
        if (token.Name ~= "font") then continue; end;
        text_size = if (token.Content["size"]) then tonumber(token.Content["size"]) :: number else text_size;
        font = if (token.Content["font"]) then (Enum.Font :: any)[token.Content["font"]] else font;
    end;

    -- Write text
    while (true) do
        --task.wait(1);
        if (self._text_properties.TextWrapped) then
            local fit_text: string? = self:_fit_words(text, font, text_size);

            if not (fit_text) then
                if (self:_get_remaining_width(self._current_line_frame) ~= self._current_line_frame.AbsoluteSize.X) then -- Line frame not empty. Create new line.
                    self:_create_line_frame(true);
                end;
                fit_text = self:_fit_letters(text, font, text_size);
            end;

            self:_letterwise_check(fit_text :: string);

            local remaining_text: string? = string.match(string.sub(text, string.len(fit_text::string) + 1, -1), "%s*(.+)");
            if not (remaining_text) then break; end;
            
            self:_create_line_frame(true);
            text = remaining_text;
        else
            self:_letterwise_check(text);
        end;
    end;
end;

--[=[
    Checks if text is letterwise and fills in text accordingly.
    @param text string -- Text to fill in.
]=]
function RichDisplay._letterwise_check(self: RichDisplay, text: string): ()
    if (self._letterwise_count == 0) then -- Text is not letterwise, fill entire frame.
        self:_create_label(text);
    else -- Text is letterwise, fill each frame letter by letter.
        for _, letter in (string.split(text, "")) do
            self:_create_label(letter);
        end;
    end;
end;

--[=[
    Applies all current tags to label.
    @param text_label TextLabel -- TextLabel to apply tags to.
]=]
function RichDisplay._apply_tags(self: RichDisplay, text_label: TextLabel): ()
    --[=[
        Pools attributes together to avoid applying multiple tags more than once.
        For example: "<font size=\"35\"><font color=\"00FF00\">Hello world!</font></font>
        Without attribute pooling, this would apply the size and color in two separate function calls.
    ]=]
    local pooled_attributes: {[string]: {[string]: any}} = {};
    for _, token: RichFormat.RichToken in (self._token_stack :: any) do
        pooled_attributes[token.Name] = pooled_attributes[token.Name] or {};
        for attribute_name: string, attribute_value: string in (token.Content) do
            pooled_attributes[token.Name][attribute_name] = attribute_value;
        end;
    end;

    for tag_name: string, tag_attributes: RichFormat.RichToken in (pooled_attributes) do
        if not (self._rich_text.Tags[tag_name]) then warn(`{tag_name} is not a valid member of self._rich_text.Tags! Try using a valid tag format!`); continue; end;

        for _, con in (self._rich_text.Tags[tag_name].Apply(text_label, tag_attributes)) do -- Adds connection to maid for future cleanup.
            self._maid:Add(con);
        end;
    end;
end;

--[=[
    Applies text properties if provided upon creation of RichDisplay class.
    @param text_label TextLabel -- Label to apply properties to.
]=]
function RichDisplay._apply_properties(self: RichDisplay, text_label: TextLabel): ()
    assert(text_label, "Invalid or no TextLabel present in the function params!");
    if not (next(self._text_properties)) then return; end; -- Guard clause in case properties are empty.
    for property_name: string, property_value: any in (self._text_properties) do
        (text_label :: any)[property_name] = property_value;
    end; 
end;

--[=[
    Warns if text property isn't set correctly in properties table and removes invalid values.
]=]
function RichDisplay._validate_text_properties(self: RichDisplay): ()
    if not (next(self._text_properties)) then return; end;
    local valid_label: TextLabel = Instance.new("TextLabel");
    for property_name: string, property_value: any in (self._text_properties) do
        local label_property = (valid_label :: any)[property_name];
        if (label_property ~= nil) and (typeof(label_property) == typeof(property_value)) then continue; end;
        warn(`Property ({property_name} = {property_value}) is not a valid property of TextLabel!`);
        self._text_properties[property_name] = nil;
    end;

    valid_label:Destroy();
end;

--[=[
    Creates the letter/word label and makes it a child of self._text_container.
    @param text string -- The letter as a string to be converted into a TextLabel.
    @param letter_index number -- The index of the letter in the text body.
    @return label TextLabel -- The letter as a TextLabel object.
]=]
function RichDisplay._create_label(self: RichDisplay, text: string): TextLabel
    local label_frame: Frame = Instance.new("Frame"); -- Frame the letter gets contained in.
    label_frame.BackgroundTransparency = 1;
    --label_frame.AutomaticSize = Enum.AutomaticSize.XY;
    label_frame.LayoutOrder = self._text_index;
    local text_size: Vector2 = TextService:GetTextSize(text, self._text_properties.TextSize, self._text_properties.Font, (Vector2.one * math.huge));
    label_frame.Size = UDim2.fromOffset(text_size.X, 0);

    self._current_line_frame.Size = UDim2.fromOffset(0, self._current_line_frame.Size.Y.Offset); -- Line frame size. Resets X to zero.

    local label: TextLabel = self._maid:Add(Instance.new("TextLabel"));
    self:_apply_properties(label);
    label.Size = UDim2.fromScale(1, 1);
    label.Name = "RichLabel";
    --label.AutomaticSize = Enum.AutomaticSize.XY;
    label.BackgroundTransparency = 1;
    label.Text = text or "";
    label.RichText = true;
    label.TextWrapped = false;
    label.LayoutOrder = (#self._current_line_frame:GetChildren() - 1);
    label.Parent = label_frame;

    label_frame.Parent = self._current_line_frame;
    self:_apply_tags(label); -- Apply richtext tags to label.

    return label;
end;

--[=[
    Creates the list layout object.
    @param fill_direction Enum.FillDirection -- The fill direction the list layout will use.
    @return list_layout UIListLayout -- UIListLayout object to sort letter labels.
]=]
function RichDisplay._create_list_layout(self: RichDisplay, fill_direction: Enum.FillDirection): UIListLayout
    local list_layout: UIListLayout = Instance.new("UIListLayout");
    list_layout.Name = "RichDisplayLayout";
    list_layout.FillDirection = fill_direction;

    if (fill_direction == Enum.FillDirection.Vertical) then -- Line frame layout
        list_layout.HorizontalFlex = Enum.UIFlexAlignment.Fill;
        list_layout.VerticalAlignment = (Enum.VerticalAlignment :: any)[self._text_properties.TextYAlignment.Name];
    else -- Letter layout
        list_layout.VerticalFlex = Enum.UIFlexAlignment.Fill;
        list_layout.HorizontalAlignment = (Enum.HorizontalAlignment :: any)[self._text_properties.TextXAlignment.Name];
        list_layout.ItemLineAlignment = Enum.ItemLineAlignment.End;
    end;
    return list_layout;
end;

--[=[
    Creates a new line frame and sets it to the _current_line_frame variables.
    @param is_new_line boolean -- Whether to treate this as a new line/line break.
]=]
function RichDisplay._create_line_frame(self: RichDisplay, is_new_line: boolean): ()
    local line_frame: Frame = Instance.new("Frame");
    line_frame.Name = "TextLine";
    line_frame.BackgroundTransparency = 1;
    line_frame.Size = UDim2.fromOffset(0, self._text_properties.TextSize);

    local line_layout: UIListLayout = self:_create_list_layout(Enum.FillDirection.Horizontal);
    line_layout.Parent = line_frame;

    if (is_new_line) then
        local new_frame: Frame = Instance.new("Frame");
        new_frame.Name = "LineBreak";
        new_frame.BackgroundTransparency = 1;
        new_frame.Size = UDim2.fromOffset(0, (self._current_line_frame.Size.Y.Offset * (self._text_properties.LineHeight - 1)));
        new_frame.Parent = self._text_container;
    end;

    line_frame.Parent = self._text_container;
    self._current_line_frame = line_frame; -- Updates current_line_frame variable if line is not a break line. Needed for other functions.
end;

--[=[
    Creates the container in which text will be stored in. A folder that rests within the TextLabel parent.
    @return Folder -- The container for the line frames and letters.
]=]
function RichDisplay._create_text_container(self: RichDisplay): Folder
    local text_container: Folder = Instance.new("Folder");
    text_container.Name = "RichTextContainer";
    text_container.Parent = self._origin_label;
    return text_container;
end;

--[=[
    Returns the next group of words that fits onto text line.
    @param text string -- Text to attempt to fit.
    @param font Enum.Font -- The font of the text.
    @param text_size number -- The size of the text.
    @return fitted_text string -- The text cut down to fit text line.
]=]
function RichDisplay._fit_words(self: RichDisplay, text: string, font: Enum.Font, text_size: number): string?
    local remaining_width: number = self:_get_remaining_width(self._current_line_frame);
    local words_table: {string} = {};

    local pattern: string;
    local text_chunk: string;
    local last_chunk: string = "";
    for word: string in (string.gmatch(text, "[%w%p]+")) do -- Loops through words and breaks out if word cant fit.
        table.insert(words_table, self:_sanitize_text(word));
        pattern = "^%s*" .. table.concat(words_table, "%s*");
        text_chunk = string.match(text, pattern); -- Grabs the chunk of text from the text param in relation to the word currently iterated to.

        local text_bounds: Vector2 = TextService:GetTextSize(text_chunk, text_size, font, (Vector2.one * math.huge));
        if (text_bounds.X > remaining_width) then
            --table.remove(words_table, #words_table);
            break;
        end;
        last_chunk = text_chunk;
    end;

    return if (string.len(last_chunk) ~= 0) then last_chunk else nil; 
end;

--[=[
    Returns the next group of letters that fits onto text line. This should only be used if _fit_words fails.
    @param text string -- Text to attempt to fit.
    @param font Enum.Font -- The font of the text.
    @param text_size number -- The size of the text.
    @return fitted_text string -- The text cut down to fit text line.
]=]
function RichDisplay._fit_letters(self: RichDisplay, text: string, font: Enum.Font, text_size: number): string?
    local remaining_width: number = self:_get_remaining_width(self._current_line_frame);
    for count = 1, string.len(text) do
        local text_bounds: Vector2 = TextService:GetTextSize(string.sub(text, 1, count), self._text_properties.TextSize, self._text_properties.Font, (Vector2.one * math.huge));
        if (text_bounds.X > remaining_width) then return string.sub(text, 1, (count - 1)); end;
    end;
    return text;
end;

--[=[
    Inserts escape character (%) before any magic characters within a string to avoid problems with string patterns.
    @param text string -- The text to be 'sanitized'
    @param sanitized_text string -- The text that has been 'sanitized'
]=]
function RichDisplay._sanitize_text(self: RichDisplay, text: string): string
    local sanitized_text: string = "";
    for _, letter in string.split(text, "") do
        if (table.find(MAGIC_CHARACTERS, letter)) then
            sanitized_text ..= "%";
        end;
        sanitized_text ..= letter;
    end;
    return sanitized_text;
end;

--[=[
    Gets the remaining width of the specified line frame.
    @param line_frame Frame -- The line frame that will contain the letters/words.
    @return number -- The remaining width on the X axis of the line frame.
]=]
function RichDisplay._get_remaining_width(self: RichDisplay, line_frame: Frame): number
    local size_sum: number = 0;
    for _, frame in (line_frame:GetChildren()) do
        if not (frame:IsA("Frame")) then continue; end;
        size_sum += frame.AbsoluteSize.X;
    end;
    return (line_frame.AbsoluteSize.X - size_sum);
end;

--[=[
    Gets the properties of the given TextLabel object and converts them to a table.
    @param text_label TextLabel -- The text label to grab properties from.
    @return table {[string]: any} -- The table full of TextLabel properties.
]=]
function RichDisplay._get_properties_from_label(self: RichDisplay, text_label: TextLabel): {[string]: any}
    return {
        TextSize = text_label.TextSize;
        Font = text_label.Font;
        LineHeight = text_label.LineHeight;
        TextColor3 = text_label.TextColor3;
        TextStrokeColor3 = text_label.TextStrokeColor3;
        TextStrokeTransparency = text_label.TextStrokeTransparency;
        TextTransparency = text_label.TextTransparency;
        TextXAlignment = text_label.TextXAlignment;
        TextYAlignment = text_label.TextYAlignment;
        TextWrapped = text_label.TextWrapped;
    };
end;

--[=[
    Initializes the RichDisplay object.
]=]
function RichDisplay.Init(self: RichDisplay): ()
    self:_validate_text_properties(); -- Ensures text properties are valid.
    self._list_layout.Parent = self._text_container;
end;

--[=[
    Cleans up the RichDisplay object and sets it's metatable to nil.
]=]
function RichDisplay.Destroy(self: RichDisplay): ()
    self._maid:DoCleaning();
    setmetatable(self :: any, nil);
end;

return RichDisplay;