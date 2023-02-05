--[[
The format goes like this:
```lua
    nameOfState = {
        min = number, -- This is optional, if you set this, you can clamp the state to a minimum value.
        max = number, -- This is optional, if you set this, you can clamp the state to a maximum value.
        startingValue = any, -- This is required, this will set a value to make the state start with when the state gets assigned for the first time.
        interval = number, -- This is optional, if you set this, it will add the number provided every x amount of minutes to the state, where x is defined by the IntervalTime variable.
        label = string, -- This is optional, you can use this label in your resources.
        stateType = string, -- This is optional, if left empty it will default to 'player', the options that this takes is either 'player', 'global', 'entity' or 'all'. This defines what kind of state bag is used
    },
```
]]
States = {
    hunger = {
        min = 0,
        max = 100,
        startingValue = 100,
        interval = -1,
        label = 'Hunger',
        stateType = 'player'
    },
    thirst = {
        min = 0,
        max = 100,
        startingValue = 100,
        interval = -1,
        label = 'Thirst',
        stateType = 'player'
    },
}

IntervalTime = 5 -- Time that the interval triggers in minutes.
SaveTime = 5 -- Time that it takes to save in minutes.