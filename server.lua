local playerStates = {}
local stateBags = {}

--#region Functions

---Get the license identifier of the player
---@param source number
---@return string | nil
local function getPlayerIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if identifier:find('license') then
            return identifier
        end
    end
end

---Initialize the resource
---@param source? number | string
local function init(source)
    if not source then
        -- Initialize state bag handlers for all states
        for state in pairs(States) do
            ---@diagnostic disable-next-line: param-type-mismatch
            stateBags[state] = AddStateBagChangeHandler(state, nil, function(bagName, _, value)
                local player = GetPlayerFromStateBagName(bagName)
                if player == 0 then return end

                if not playerStates[player] or not playerStates[player].states then return end

                playerStates[player].states[state] = value
            end)
        end
    end

    local players = source and {source} or GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i]) --[[@as number]]
        local identifier = getPlayerIdentifier(src)
        if not identifier then return end
        local kvp = GetResourceKvpString(identifier)
        playerStates[src] = {
            source = src,
            identifier = identifier,
            states = kvp and json.decode(kvp) or {}
        }

        local isEmpty = table.type(playerStates[src].states) == 'empty'
        local stateBag = Player(src).state
        for state, data in pairs(States) do
            local newData = data
            newData.value = not isEmpty and stateBag[state].value or data.startingValue
            stateBag:set(state, newData, true)
        end
    end
end

---Get a certain state from a player
---@param source number
---@param state string
---@return table | nil
exports('getStateFromPlayer', function(source, state)
    return playerStates[source] and playerStates[source].states[state] or nil
end)

---Add a new state to the config (only for the runtime of the script)
---@param state string
---@param data table
exports('addState', function(state, data)
    if States[state] then return end

    States[state] = data

    ---@diagnostic disable-next-line: param-type-mismatch
    stateBags[state] = AddStateBagChangeHandler(state, nil, function(bagName, _, value)
        local player = GetPlayerFromStateBagName(bagName)
        if player == 0 then return end

        if not playerStates[player] or not playerStates[player].states then return end

        playerStates[player].states[state] = value
    end)

    local stateToAdd = data
    stateToAdd.value = data.startingValue
    for source in pairs(playerStates[source]) do
        Player(source).state:set(state, stateToAdd, true)
    end
end)

---Remove a state from the config (only for the runtime of the script)
---@param state string
exports('removeState', function(state)
    if not States[state] then return end

    States[state] = nil
    RemoveStateBagChangeHandler(stateBags[state])
    stateBags[state] = nil
end)

---Add a number to a state
---@param source number
---@param state string
---@param amount number
local function addToState(source, state, amount)
    if not source or not state or not amount or type(state) ~= 'string' or type(amount) ~= 'number' or not States[state] or not playerStates[source] or not playerStates[source].states[state] or type(playerStates[source].states[state]?.value) ~= 'number' then return end

    local stateBag = Player(source)
    local curState = stateBag.state[state]
    if curState.max and curState.value + amount > curState.max then return end

    curState.value += amount
    stateBag.state:set(state, curState, true)
end

exports('addToState', addToState)

---Subtract a number to a state
---@param source number
---@param state string
---@param amount number
exports('subtractFromState', function(source, state, amount)
    if not source or not state or not amount or type(state) ~= 'string' or type(amount) ~= 'number' or not States[state] or not playerStates[source] or not playerStates[source].states[state] or type(playerStates[source].states[state]?.value) ~= 'number' then return end

    local stateBag = Player(source)
    local curState = stateBag.state[state]
    if curState.min and curState.value - 1 < curState.min then return end

    curState.value -= amount
    stateBag.state:set(state, curState, true)
end)

---Set a state's value
---@param source number
---@param state string
---@param value any
exports('setState', function(source, state, value)
    if not source or not state or type(state) ~= 'string' or not playerStates[source] or not playerStates[source].states[state] then return end

    local stateBag = Player(source)
    local curState = stateBag.state[state]
    if type(curState.value) == 'number' and ((curState.min and curState.value - 1 < curState.min) or curState.max and curState.value + 1 > curState.max) then return end

    curState.value = value
    stateBag.state:set(state, curState, true)
end)

--#endregion Functions

--#region Events

AddEventHandler('playerJoining', function()
    init(source)
end)

AddEventHandler('playerDropped', function()
    local data = playerStates[source]
    if not data then return end

    SetResourceKvp(data.identifier, json.encode(data.states))
    playerStates[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    init()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, data in pairs(playerStates) do
        SetResourceKvp(data.identifier, json.encode(data.states))
    end
end)

--#endregion Events

--#region Threads

CreateThread(function()
    local intervalTime = IntervalTime * 60000
    while true do
        Wait(intervalTime)
        for source, data in pairs(playerStates) do
            for state, stateData in pairs(data.states) do
                if stateData.interval and type(stateData.interval) == 'number' then
                    addToState(source, state, stateData.interval)
                end
            end
            SetResourceKvp(data.identifier, json.encode(data.states))
        end
    end
end)

CreateThread(function()
    local saveTime = SaveTime * 60000
    while true do
        Wait(saveTime)
        for _, data in pairs(playerStates) do
            SetResourceKvp(data.identifier, json.encode(data.states))
        end
    end
end)

--#endregion Threads