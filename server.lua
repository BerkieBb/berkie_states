local stateHolders = {}

--#region Functions

---Get the license identifier of the player
---@param source number
---@return string | nil
local function getPlayerIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if identifier:find('license2') or identifier:find('license') then
            return identifier
        end
    end
end

---Add the contents of the second array to the first
---@param array1 any[]
---@param array2 any[]
---@return any[]
local function addToArray(array1, array2)
    local amount = #array1 + 1
    local iterator = 1
    for i = amount, amount + #array2 do
        array1[i] = array2[iterator]
        iterator += 1
    end

    return array1
end

---Initialize the resource
---@param source? number | string
local function init(source)
    local players = source and {source} or GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i]) --[[@as number]]
        local identifier = getPlayerIdentifier(src)
        if not identifier then return end
        local kvp = GetResourceKvpString(identifier)
        local states = kvp and json.decode(kvp) or {}
        local stateBag = Player(src).state
        for state, data in pairs(States) do
            if data.stateType == 'player' then
                local newData = table.clone(data)
                newData.value = stateBag[state] and stateBag[state].value or states[state] and states[state].value or data.startingValue
                stateBag:set(state, newData, true)
            end
        end
        stateHolders[#stateHolders + 1] = {
            type = 'player',
            identifier = identifier,
            source = src
        }
    end

    if source then return end

    ---@diagnostic disable-next-line: param-type-mismatch
    local entities = addToArray(addToArray(GetAllPeds(), GetAllVehicles()), GetAllObjects()) --[[ @as number[] ]]
    for i = 1, #entities do
        local entity = entities[i]
        local stateBag = Entity(entity).state
        for state, data in pairs(States) do
            if data.stateType == 'entity' then
                local newData = table.clone(data)
                newData.value = stateBag[state] and stateBag[state].value or data.startingValue
                stateBag:set(state, newData, true)
            end
        end
        stateHolders[#stateHolders + 1] = {
            type = 'entity',
            identifier = NetworkGetNetworkIdFromEntity(entity),
            handle = entity
        }
    end

    local kvp = GetResourceKvpString('global')
    local states = kvp and json.decode(kvp) or {}
    for state, data in pairs(States) do
        if data.stateType == 'global' then
            local newData = table.clone(data)
            newData.value = GlobalState[state] and GlobalState[state].value or states[state] and states[state].value or data.startingValue
            GlobalState:set(state, newData, true)
        end
    end
end

---Add a new state to the config (only for the runtime of the script)
---@param state string
---@param data table
exports('addState', function(state, data)
    if States[state] then return end

    data.stateType = data.stateType and string.lower(data.stateType) or nil
    data.stateType = (not data.stateType or data.stateType ~= 'global' or data.stateType ~= 'entity' or data.stateType ~= 'player' or data.stateType ~= 'all') and 'player' or data.stateType
    States[state] = data

    local stateToAdd = table.clone(data)
    stateToAdd.value = data.startingValue

    for i = 1, #stateHolders do
        local holder = stateHolders[i]
        if holder then
            if holder.type == 'player' and (data.stateType == 'player' or data.stateType == 'all') then
                Player(holder.source).state:set(state, stateToAdd, true)
            elseif holder.type == 'entity' and (data.stateType == 'entity' or data.stateType == 'all') then
                local entity = DoesEntityExist(holder.handle) and holder.handle or NetworkGetEntityFromNetworkId(holder.identifier)
                if DoesEntityExist(entity) then
                    Entity(entity).state:set(state, stateToAdd, true)
                else
                    table.remove(stateHolders, index) -- This reorders the table indexes so it's still an array
                end
            end
        end
    end

    if data.stateType == 'global' or data.stateType == 'all' then
        GlobalState:set(state, stateToAdd, true)
    end
end)

---Remove a state from the config (only for the runtime of the script)
---@param state string
---@param removeFromStateBags boolean If set to true, this will remove the state from all active state bags as well
exports('removeState', function(state, removeFromStateBags)
    if not States[state] then return end

    States[state] = nil

    if not removeFromStateBags then return end

    for i = 1, #stateHolders do
        local holder = stateHolders[i]
        if holder then
            if holder.type == 'player' then
                Player(holder.source).state:set(state, nil, true)
            elseif holder.type == 'entity' then
                local entity = DoesEntityExist(holder.handle) and holder.handle or NetworkGetEntityFromNetworkId(holder.identifier)
                if DoesEntityExist(entity) then
                    Entity(entity).state:set(state, nil, true)
                else
                    table.remove(stateHolders, index) -- This reorders the table indexes so it's still an array
                end
            end
        end
    end

    GlobalState:set(state, nil, true)
end)

exports('getStates', function()
    return States
end)

--#endregion Functions

--#region Events

AddEventHandler('playerJoining', function()
    init(source)
end)

AddEventHandler('playerDropped', function()
    local holder, index
    for i = 1, #stateHolders do
        local stateHolder = stateHolders[i]
        if stateHolder and stateHolder.source == source then
            holder, index = stateHolders[i], i
        end
    end

    if not holder then return end

    local stateBag = Player(holder.source).state
    local states = {}
    for state, data in pairs(States) do
        if data.stateType == 'player' or data.stateType == 'all' then
            states[state] = stateBag[state]
        end
    end

    SetResourceKvp(holder.identifier, json.encode(states))

    table.remove(stateHolders, index) -- This reorders the table indexes so it's still an array
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    init()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #stateHolders do
        local holder = stateHolders[i]
        if holder then
            if holder.type == 'player' then
                local stateBag = Player(holder.source).state
                local states = {}
                for state, data in pairs(States) do
                    if data.stateType == 'player' or data.stateType == 'all' then
                        states[state] = stateBag[state]
                    end
                end

                SetResourceKvp(holder.identifier, json.encode(states))
            end
        end
    end

    local states = {}
    for state, data in pairs(States) do
        if data.stateType == 'global' or data.stateType == 'all' then
            states[state] = GlobalState[state]
        end
    end

    SetResourceKvp('global', json.encode(states))
end)

--#endregion Events

--#region Threads

CreateThread(function()
    -- stateType fallback
    for _, data in pairs(States) do
        data.stateType = data.stateType and string.lower(data.stateType) or nil
        data.stateType = (not data.stateType or data.stateType ~= 'global' or data.stateType ~= 'entity' or data.stateType ~= 'player' or data.stateType ~= 'all') and 'player' or data.stateType
    end

    local intervalTime = IntervalTime * 60000
    while true do
        Wait(intervalTime)
        for i = 1, #stateHolders do
            local holder = stateHolders[i]
            if holder then
                if holder.type == 'player' then
                    local stateBag = Player(holder.source).state
                    for state, data in pairs(States) do
                        if data.stateType == 'player' or data.stateType == 'all' then
                            local bag = stateBag[state]
                            if bag and type(bag.value) == 'number' then
                                local newData = table.clone(bag)
                                newData.value = (type(data.min) ~= 'number' and newData.value or newData.value < data.min and data.min) or (type(data.max) ~= 'number' and newData.value or newData.value > data.max and data.max) or newData.value
                                if type(data.interval) == 'number' then
                                    newData.value += data.interval
                                end

                                stateBag:set(state, newData, true)
                            end
                        end
                    end
                elseif holder.type == 'entity' then
                    local entity = DoesEntityExist(holder.handle) and holder.handle or NetworkGetEntityFromNetworkId(holder.identifier)
                    if DoesEntityExist(entity) then
                        local stateBag = Entity(entity).state
                        for state, data in pairs(States) do
                            if data.stateType == 'entity' or data.stateType == 'all' then
                                local bag = stateBag[state]
                                if bag and type(bag.value) == 'number' then
                                    local newData = table.clone(bag)
                                    newData.value = (type(data.min) ~= 'number' and newData.value or newData.value < data.min and data.min) or (type(data.max) ~= 'number' and newData.value or newData.value > data.max and data.max) or newData.value
                                    if type(data.interval) == 'number' then
                                        newData.value += data.interval
                                    end

                                    stateBag:set(state, newData, true)
                                end
                            end
                        end
                    else
                        table.remove(stateHolders, index) -- This reorders the table indexes so it's still an array
                    end
                end
            end
        end

        for state, data in pairs(States) do
            if data.stateType == 'global' or data.stateType == 'all' then
                local bag = GlobalState[state]
                if bag and type(bag.value) == 'number' then
                    local newData = table.clone(bag)
                    newData.value = (type(data.min) ~= 'number' and newData.value or newData.value < data.min and data.min) or (type(data.max) ~= 'number' and newData.value or newData.value > data.max and data.max) or newData.value
                    if type(data.interval) == 'number' then
                        newData.value += data.interval
                    end

                    stateBag:set(state, newData, true)
                end
            end
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        local entities = addToArray(addToArray(GetAllPeds(), GetAllVehicles()), GetAllObjects()) --[[ @as number[] ]]
        for i = 1, #entities do
            local entity = entities[i]

            for i2 = 1, #stateHolders do
                local holder = stateHolders[i2]
                if holder.type == 'entity' and (holder.handle == entity or holder.identifier == NetworkGetNetworkIdFromEntity(entity)) then
                    goto endLoop
                end
            end

            local stateBag = Entity(entity).state

            for state, data in pairs(States) do
                if data.stateType == 'entity' then
                    local newData = table.clone(data)
                    newData.value = stateBag[state] and stateBag[state].value or data.startingValue
                    stateBag:set(state, newData, true)
                end
            end
            stateHolders[#stateHolders + 1] = {
                type = 'entity',
                identifier = NetworkGetNetworkIdFromEntity(entity),
                handle = entity
            }
            :: endLoop ::
        end
    end
end)

CreateThread(function()
    local saveTime = SaveTime * 60000
    while true do
        Wait(saveTime)
        for i = 1, #stateHolders do
            local holder = stateHolders[i]
            if holder then
                if holder.type == 'player' then
                    local stateBag = Player(holder.source).state
                    local states = {}
                    for state, data in pairs(States) do
                        if data.stateType == 'player' or data.stateType == 'all' then
                            states[state] = stateBag[state]
                        end
                    end

                    SetResourceKvp(holder.identifier, json.encode(states))
                elseif holder.type == 'entity' then
                    local entity = DoesEntityExist(holder.handle) and holder.handle or NetworkGetEntityFromNetworkId(holder.identifier)
                    if not DoesEntityExist(entity) then
                        table.remove(stateHolders, index) -- This reorders the table indexes so it's still an array
                    end
                end
            end
        end

        local states = {}
        for state, data in pairs(States) do
            if data.stateType == 'global' or data.stateType == 'all' then
                states[state] = GlobalState[state]
            end
        end

        SetResourceKvp('global', json.encode(states))
    end
end)

--#endregion Threads