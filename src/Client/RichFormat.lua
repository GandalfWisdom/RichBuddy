--!strict
local require = require(script.Parent.loader).load(script) :: any;
local Maid = require("Maid");
local StackBuddy = require("StackBuddy");

local RichFormat = {};
RichFormat.__index = RichFormat;
RichFormat.ClassName = "RichFormat";

-- Variables
local STRING_PATTERN_A: string = "<.->";
local VALID_TAG_PATTERN: string = "<%s*/?%a+(.-)%s*>";
--local SUBSTRING_PATTERN: string = "%s*%a+%s*=%s*\".-\"";
local NAME_PATTERN: string = "%s*/?%a+%s*";
local ATTRIBUTE_PATTERN: string = "%a+%s*=%s*\".-\"";


export type RichToken = {
    Name: string,
    IsOpening: boolean,
    Content: {[string]: string},
};

type RichTag = {
    Letterwise: boolean,
    ValidAttributes: {string},
    Apply: (TextLabel, ...any) -> {RBXScriptConnection?},
};

export type RichFormat = typeof(setmetatable(
    {} :: {
        _maid: Maid.Maid,
        _raw_text: string,
        _text: string,
        Tags: {[string]: RichTag},
        _tokens: {RichToken | string},
        _token_index: number,
    },
    {} :: typeof({ __index = RichFormat })
));

--[=[
    Constructs a new RichFormat object.
    @param text string -- The text to be converted to RichText
    @return RichFormat
]=]
function RichFormat.new(text: string): RichFormat
    local self: RichFormat = setmetatable({} :: any, RichFormat);
    self._maid = Maid.new();
    self._raw_text = text or ""; -- Original copy of raw text
    self._text = text or ""; -- Text that gets parsed through
    self.Tags = require(script.Parent.RichTags);
    self._tokens = {};
    self._token_index = 0;
    self:Init();
    return self;
end;

--[=[
    Parses through text and creates a table of tokens by 
    slowly breaking the text down into chunks each iteration.
]=]
function RichFormat._parse(self: RichFormat): ()
    while (string.len(self._text) > 0) do
        local tag_start, tag_end = string.find(self._text, STRING_PATTERN_A);

        local is_tag: boolean = tag_start == 1;
        local text_chunk_end: number = if (is_tag) then (tag_end :: number) elseif (tag_start) then (tag_start - 1) else (string.len(self._text));
        local text_chunk: string = string.sub(self._text, 1, text_chunk_end);

        if (is_tag) then
            table.insert(self._tokens, self:_read_tag(text_chunk) or text_chunk);
        else
            table.insert(self._tokens, text_chunk);
        end;

        self._text = string.sub(self._text, text_chunk_end + 1, -1); -- Removes processed chunk from string, allowing next iteration of loop to process the next chunk.
    end;
end;

--[=[
    Reads text chunk and returns RichToken table.
    @param text_chunk string -- The text chunk to be processed and converted into a RichToken table.
]=]
function RichFormat._read_tag(self: RichFormat, text_chunk: string): RichToken?
    local valid_tag: string = string.match(text_chunk, VALID_TAG_PATTERN);
    if not (valid_tag) then warn(`Tag: ({text_chunk}) could not be read!`); return; end; -- Guard clause for invalid text_chunk

    while (string.len(valid_tag) > 0) do
		local attribute = string.match(valid_tag, "^%s+%a+%s*=%s*\".-\"")
		if not (attribute) then -- Tag is invalid, syntax error with attributes
			warn(`Parsed Tag ({text_chunk}) could not be read.`);
			return;
		end;
		valid_tag = string.sub(valid_tag, string.len(attribute) + 1, -1);
	end;

    text_chunk = string.sub(text_chunk, 2, -2); -- Strips away first and last character from tag (<>)

    local name_chunk: string = string.match(text_chunk, NAME_PATTERN) :: string;
    local name_string: string = string.gsub(name_chunk, "[%s/]", "");
    local is_start_tag: boolean = string.find(name_chunk, "/") == nil;

    local attribute_chunk: string = string.sub(text_chunk, string.len(name_chunk) + 1, -1);
    local attribute_table: {[string]: any} = {};
    for attribute in attribute_chunk:gmatch(ATTRIBUTE_PATTERN) do
        attribute = string.gsub(attribute, "%s", ""); -- Remove spaces from attribute.
        local attribute_name: string, attribute_value: string = table.unpack(string.split(attribute, "="));
        attribute_value = attribute_value:sub(2, -2); -- Remove quotation marks
        attribute_table[attribute_name] = attribute_value;
    end;
    return {
        Name = name_string,
        IsOpening = is_start_tag,
        Content = attribute_table,
    };
end;

--[=[
    Validates token items in tokens table to ensure they are formatted correctly.
    @return is_valid boolean -- Whether tokens are valid.
]=]
function RichFormat._validate_tokens(self: RichFormat): boolean
    local token_stack: StackBuddy.StackBuddy = self._maid:Add(StackBuddy.new());

    for _, token in ipairs(self._tokens) do
        if (typeof(token) == "string") then continue; end; -- Guard clause. Continue if token is not a table.
        if (token.Name == "br") then continue; end; -- <br> will not get validated as it doesn't need a closing tag.

        -- Checks if tag module exists
        if not (self.Tags[token.Name]) then
            warn(`Token ({token.Name}) is invalid!)`);
            return false;
        end;

        -- Compares token attributes to tag's validattributes table to check for invalidities
        for attribute_name, _ in (token.Content) do
            if not (table.find(self.Tags[token.Name].ValidAttributes, attribute_name)) then
                warn(`Attribute ({attribute_name}) is invalid and not found within {token.Name} tag!`);
                return false;
            end;
        end;

        if (token.IsOpening) then
            token_stack:Push(token.Name);
        else
            if (next(token.Content)) then warn(`Defined attributes to the end tag </{token.Name}>. Attributes should only be defined within the start tag.`); end;

            local top_tag: string = token_stack:Pop() :: string;
            if (top_tag ~= token.Name) then
                warn(`Invalid token formatting. Expected (</{token.Name}>), got (</{top_tag}>).`);
                return false;
            end;
        end;
    end;

    if not (token_stack:IsEmpty()) then
        for _, rich_tag: RichToken in ipairs(token_stack:Table()) do
            warn(`Missing closing tag: </{rich_tag.Name}>`);
        end;
        return false;
    end;
    return true;
end;

--[=[
    Returns tokens table
    @return _tokens table -- Tokens table.
]=]
function RichFormat.GetTokens(self: RichFormat): { RichToken | string }
    return self._tokens;
end;

--[=[
    Removes token from tokens table.
]=]
function RichFormat.RemoveToken(self: RichFormat, token: number | string | RichToken): ()
    if (typeof(token) == "number") then
        table.remove(self._tokens, token);
    else
        local table_index: number? = table.find(self._tokens, token);
        if (table_index) then table.remove(self._tokens, table_index); end;
    end;
end;

--[=[
    Initializes the RichFormat object.
]=]
function RichFormat.Init(self: RichFormat): ()
    self:_parse();
    self:_validate_tokens();
end;

--[=[
    __tostring metamethod. Returns the raw text of the class.
    @return self._raw_text string -- The raw text values.
]=]
function RichFormat.__tostring(self: RichFormat): string
    return self._raw_text;
end;

--[=[
    Cleans up the RichFormat object and sets it's metatable to nil.
]=]
function RichFormat.Destroy(self: RichFormat): ()
    self._maid:DoCleaning();
    setmetatable(self :: any, nil);
end;

return RichFormat;