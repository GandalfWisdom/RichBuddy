# RichBuddy

A simple rich text display class for Roblox.

## Requirements
This module <b>requires</b> Quenty's [Nevermore](https://github.com/Quenty/NevermoreEngine) engine to function.

## Features
Convert any [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel) object to a rich text capable label with features such as:

* Standard Roblox richtext implementation.
* Typewriter effects and styles such as "fade" and "drop".
* Shake, wave, and other animated text options.

## Usage
Initialize your RichBuddy object:
```lua
local RichBuddy = require(path.to.richbuddy);
local rich_display = RichBuddy.new(text_label, `<write speed="0.05" style="drop"><b>Example text!</b></write>`);
```

## Installation
StackBuddy supports [Nevermores](https://github.com/Quenty/NevermoreEngine) npm package installation method. 

Simply type ```npm install @gandalfwisdom/richbuddy``` in your CLI on your project to install.