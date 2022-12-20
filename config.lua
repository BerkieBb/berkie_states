--[[
The format goes like this:
```lua
    nameOfState = {
        min = number, -- This is optional, if you set this, you can clamp the state to a minimum value.
        max = number, -- This is optional, if you set this, you can clamp the state to a maximum value.
        startingValue = number, -- This is required, this will set a value to make the state start with when a player gets assigned it for the first time.
        interval = number, -- This is optional, if you set this, it will add the number provided every x amount of minutes to the state, where x is defined by the IntervalTime variable.
        label = string, -- This is optional, you can use this label in your resources.
    },
```
]]
States = {
    hunger = {
        min = 0,
        max = 100,
        startingValue = 100,
        interval = -1,
        label = 'Hunger'
    },
    thirst = {
        min = 0,
        max = 100,
        startingValue = 100,
        interval = -1,
        label = 'Thirst'
    },
}

IntervalTime = 5 -- Time that the interval triggers in minutes.
SaveTime = 5 -- Time that it takes to save in minutes.