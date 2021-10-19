local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RepModules = ReplicatedStorage.Modules
local MMRBoxData = require(RepModules.MMRBoxData)

local Utility = ReplicatedStorage.Utility
local General = require(Utility.General)

local SerModules = ServerScriptService.Modules
local Teleport = require(SerModules.Teleport)

local Remotes = ReplicatedStorage.Remotes
local QueueRemote = Remotes.QueueRemote

local SUBSCRIBE_RETRY_COUNT = 5
local PUBLISH_RETRY_COUNT = 5
local ADD_QUEUE_RETRY_COUNT = 5
local READ_QUEUE_RETRY_COUNT = 5
local MAX_WEIGHT_PER_PARTY = 3

local MAX_QUEUE_SIZE = 8
local MAX_POLL_TIME = 5
local MAX_QUEUE_EXISTENCE = 300
local MAX_VALIDATION_WAIT_TIME = 12
local INVISIBILITY_TIMEOUT = 2
local IDEAL_PLAYER_COUNT = 8

local DEBUG = false

local SERVER_JOB_ID = game.JobId

if RunService:IsStudio() then
    SERVER_JOB_ID = "1234-abcd-5678-ghij"
end

local NextQueueId = 0
local serverType, levelId = General:GetServerType(5154334974)

local GlobalQueues = {
    Queue1 = MemoryStoreService:GetQueue("test1", INVISIBILITY_TIMEOUT),
    Queue2 = MemoryStoreService:GetQueue("test2", INVISIBILITY_TIMEOUT),
}

local function shallowCopy(tbl)
    local newTable = {}

    for i,v in pairs(tbl) do
        newTable[i] = v
    end

    return newTable
end

local function debugPrint(message)
    if DEBUG then
        print(message)
    end
end

local function getBoxInfoForTeleport(boxNumber, teams)
    local mmrBoxInfo = MMRBoxData[boxNumber]
    local boxInfo = {
        map = mmrBoxInfo.map,
        modifiers = mmrBoxInfo.modifiers,
        event = mmrBoxInfo.event,
        difficulty = mmrBoxInfo.difficulty,
        MMR = true,
        owner = nil,
        teams = teams
    }

    return boxInfo
end

local function publishMessage(subscriptionId, message)
    local success, failMessage, failCount = nil, nil, 0

    repeat
        success, failMessage = pcall(function()
            MessagingService:PublishAsync(subscriptionId, message)
        end)

        if not success then
            failCount += 1
            task.wait(1)
        end
    until success or failCount > PUBLISH_RETRY_COUNT

    if not success then warn("PUBLISH FAILED, UNABLE TO PUBLISH QUEUESYSTEM MESSAGE: ", failMessage, subscriptionId, message) end
end

local function addToQueue(queue, value, priority)
    local success, failMessage, failCount = nil, nil, 0

    repeat
        success, failMessage = pcall(function()
            queue:AddAsync(value, MAX_QUEUE_EXISTENCE, priority)
        end)

        if not success then
            failCount += 1
            task.wait(1)
        end
    until success or failCount > ADD_QUEUE_RETRY_COUNT

    if not success then warn("QUEUE ADDASYNC FAILED, UNABLE TO ADD PLAYERS TO QUEUESYSTEM: ", failMessage, value) end

    return success
end

local function readQueue(queue)
    local nextGroupInQueue, groupIdentifier
    local success, message, failCount = nil, nil, 0

    repeat
        success, message = pcall(function()
            nextGroupInQueue, groupIdentifier = queue:ReadAsync(MAX_QUEUE_SIZE, false, MAX_POLL_TIME)
        end)

        if not success then
            failCount += 1
            task.wait(1)
        end
    until success or failCount > READ_QUEUE_RETRY_COUNT

    if not success then
        warn("READ QUEUE FAILED, COULDNT GET ANY GROUPS", message)
    end

    return success, nextGroupInQueue, groupIdentifier
end

local QueueSystem = {}
QueueSystem.Debounce = {}
QueueSystem.QueueStorage = {}
QueueSystem.WaitingForValidation = {}
QueueSystem.ForeignQueueStorage = {}

------------- Functions & Utility -------------
local function validateParty(queueSessionId)
    local queueStorageData = QueueSystem.QueueStorage[queueSessionId]

    if queueStorageData then
        if queueStorageData.valid then
            if queueStorageData.ids then
                for _,id in pairs(queueStorageData.ids) do
                    local player = Players:GetPlayerByUserId(id)
                    if not player then
                        return false
                    end
                end

                return true
            end
        end
    end

    return false
end

local function generateTeams(parties, totalPlayerCount)
    local teams = {
        ['1'] = {},
        ['2'] = {}
    }

    local teamCounts = {
        ['1'] = 0,
        ['2'] = 0
    }

    for _, partyInfo in pairs(parties) do
        local teamToAdd
        if teamCounts['1'] >= teamCounts['2'] then
            teamToAdd = '2'
        else
            teamToAdd = '1'
        end

        for _,id in pairs(partyInfo.ids) do
            local username = Players:GetNameFromUserIdAsync(id)
            teams[teamToAdd][username] = true
            teamCounts[teamToAdd] += 1
        end
    end

    return teams, math.abs(teamCounts['1'] - teamCounts['2'])
end

local function getMorePartiesForTeams(queue, playingParties, playersNeeded, currentPlayerCount)
    local success, extraPlayerGroup, extraGroupIdentifier = readQueue(queue)
    if success and extraPlayerGroup then
        local foundAParty = false
        local removeIndex = nil

        for index,party in pairs(extraPlayerGroup) do -- first try to find the exact number of players needed
            if #party.ids == playersNeeded then
                table.insert(playingParties, party)
                currentPlayerCount += #party.ids
                removeIndex = index

                foundAParty = true
                break
            end
        end

        if not foundAParty then
            local extraPlayerCount = playersNeeded
            local newFoundParties = {}
            local removeIndecies = {}

            for index,party in pairs(extraPlayerGroup) do -- if no party found, try to combine multiple parties to get enough players
                if #party.ids <= extraPlayerCount then
                    table.insert(newFoundParties, party)
                    extraPlayerCount -= #party.ids
                    table.insert(newFoundParties, index)

                    if extraPlayerCount == playersNeeded then
                        foundAParty = true
                        break
                    end
                end
            end

            if foundAParty then
                for _,party in pairs(newFoundParties) do
                    table.insert(playingParties, party)
                    currentPlayerCount += #party.ids
                end

                queue:RemoveAsync(extraGroupIdentifier)

                for _,index in pairs(removeIndecies) do
                    extraPlayerGroup[index] = "removed" -- don't requeue added parties
                end

                for _,partyInfo in pairs(extraPlayerGroup) do
                    if partyInfo ~= "removed" then
                        task.spawn(addToQueue, queue, partyInfo) -- put unused parties back in the queue
                    end
                end
            else                                             -- abort the queue group, couldn't make proper teams
                return true
            end
        else
            queue:RemoveAsync(extraGroupIdentifier)
            table.remove(extraPlayerGroup, removeIndex) -- don't requeue added party

            for _,partyInfo in pairs(extraPlayerGroup) do
                task.spawn(addToQueue, queue, partyInfo) -- put unused parties back in the queue
            end
        end
    else                                                -- abort the queue group, somes sort of error occurred
        return true
    end

    return false, currentPlayerCount
end

local function getNumberOfPlayersInGroups(groups)
    local playerCount = 0
    for _,partyInfo in pairs(groups) do
        playerCount += #partyInfo.ids
    end

    return playerCount
end

local function sendMessageToPlayers(queueSessionId, message)
    local queueStorageData = QueueSystem.QueueStorage[queueSessionId]

    if queueStorageData then
        if queueStorageData.valid then
            if queueStorageData.ids then
                for _,id in pairs(queueStorageData.ids) do
                    local player = Players:GetPlayerByUserId(id)
                    if player then
                        QueueRemote:FireClient(player, message)
                    end
                end
            end
        end
    end
end
------------- Usable Functions -------------

function QueueSystem:AddToQueue(userIds, queueNumber, queueSessionIdOverride)
    local queue = GlobalQueues["Queue"..queueNumber]

    local notDebounced = true
    if not queueSessionIdOverride then
        for _,id in pairs(userIds) do
            if QueueSystem.Debounce[id] then
                notDebounced = false
                break
            end
        end
    end

    if notDebounced then
        local queueIdToUse = queueSessionIdOverride or NextQueueId

        local success = addToQueue(queue, {
            ids = userIds,
            serverId = SERVER_JOB_ID,
            queueId = queueIdToUse,
            weight = 0
        })

        if success then
            QueueSystem.QueueStorage[queueIdToUse] = {
                ids = userIds,
                queueNumber = queueNumber,
                valid = true,
                processed = false
            }

            if not queueSessionIdOverride then
                for _,id in pairs(userIds) do
                    QueueSystem.Debounce[id] = queueIdToUse

                    local player = Players:GetPlayerByUserId(id)
                    if player then
                        QueueRemote:FireClient(player, "start", {queueId = queueIdToUse})
                    end
                end
            end

            task.delay(MAX_QUEUE_EXISTENCE + 2, function()
                if QueueSystem.QueueStorage[NextQueueId] and not QueueSystem.QueueStorage[NextQueueId].processed and QueueSystem.QueueStorage[NextQueueId].valid then
                    self:AddToQueue(userIds, queueNumber, queueIdToUse)
                end
            end)
        end

        if not queueSessionIdOverride then
            NextQueueId += 1
        end
    end
end

function QueueSystem:LeaveQueue(userId, queueSessionId)
    if not queueSessionId then
        queueSessionId = QueueSystem.Debounce[userId]
    end

    if queueSessionId then
        local partyData = QueueSystem.QueueStorage[queueSessionId]
        if partyData then
            if table.find(partyData.ids, userId) then
                sendMessageToPlayers(queueSessionId, "leave")
                QueueSystem.QueueStorage[queueSessionId].valid = false

                for _,id in pairs(partyData.ids) do
                    QueueSystem.Debounce[id] = false
                end
            end
        end
    end
end

function QueueSystem:IsDebounced(userId)
    return QueueSystem.Debounce[userId]
end

function QueueSystem:ClearQueue(queueNumber)
    local queue = GlobalQueues["Queue"..queueNumber]
    local nextGroupInQueue, groupIdentifier = queue:ReadAsync(100, false, 5)
    queue:RemoveAsync(groupIdentifier)
end

------------- Core Events & Loops -------------

function QueueSystem:MessageWatch()
    debugPrint('started message')
    local success, failMessage, failCount = nil, nil, 0
    repeat
        success, failMessage = pcall(function()
            MessagingService:SubscribeAsync(SERVER_JOB_ID, function(message)
                debugPrint('received queue message')
                local messageData = message.Data
                if messageData.action == "validate" then
                    local queueSessionId = messageData.queueId
                    local requestServerId = messageData.serverId
                   
                    local valid = validateParty(queueSessionId)

                    sendMessageToPlayers(queueSessionId, "validate")

                    publishMessage(requestServerId, {
                        action = "return-validate",
                        serverId = SERVER_JOB_ID,
                        queueId = queueSessionId,
                        status = valid
                    })
                elseif messageData.action == "return-validate" then
                    local queueStorageData = self.ForeignQueueStorage[messageData.serverId..messageData.queueId]

                    local validationStatus = messageData.status

                    local tableIndex = table.concat(queueStorageData.ids, "-").."-"..messageData.queueId
                    if validationStatus then
                        self.WaitingForValidation[tableIndex] = "ready"
                    else
                        self.WaitingForValidation[tableIndex] = "failed"
                    end
                elseif messageData.action == "join" then
                    local queueStorageData = self.QueueStorage[messageData.queueId]

                    sendMessageToPlayers(messageData.queueId, "found")

                    if queueStorageData then
                        if queueStorageData.valid then
                            if queueStorageData.ids then
                                local playerList = {}
                                for _,id in pairs(queueStorageData.ids) do
                                    table.insert(playerList, Players:GetPlayerByUserId(id))
                                end

                                for i,v in pairs(messageData.teams['1']) do
                                    debugPrint(1,i,v)
                                end
        
                                for i,v in pairs(messageData.teams['2']) do
                                    debugPrint(2,i,v)
                                end

                                queueStorageData.processed = true
                                Teleport:QueueTeleport(playerList, messageData.reservedId, messageData.numPlayers, getBoxInfoForTeleport(queueStorageData.queueNumber, messageData.teams))
                            end
                        end
                    end
                elseif messageData.action == "retry" then
                    local queueStorageData = self.QueueStorage[messageData.queueId]
                    sendMessageToPlayers(messageData.queueId, "retry")
                end
            end)
        end)
        if not success then
            failCount += 1
            task.wait(2)
        end
    until success or failCount > SUBSCRIBE_RETRY_COUNT

    if not success then warn("SERVER SUBSCRIPTION FAILED, UNABLE TO VALIDATE ANY PLAYER QUEUES: "..failMessage) end
end

function QueueSystem:GlobalWatch()
    debugPrint('started global')
    task.spawn(function()
        while true do
            for queueName, queue in pairs(GlobalQueues) do
                debugPrint("~~~"..queueName.."~~~~")
                local queueNumber = string.gsub(queueName, "Queue", "")
                queueNumber = tonumber(queueNumber)

                local mmrBoxInfo = MMRBoxData[queueNumber]
                local abortCurrentQueue = false

                local success, nextGroupInQueue, groupIdentifier = readQueue(queue)

                if success and nextGroupInQueue and getNumberOfPlayersInGroups(nextGroupInQueue) >= 2 and #nextGroupInQueue > 1 then
                    debugPrint('found group', #nextGroupInQueue)
                    queue:RemoveAsync(groupIdentifier) -- remove it asap so another server doesn't pick it up

                    local currentPlayerCount = 0
                    local playingParties = {}
                    
                    local headIndex = 1

                    while #nextGroupInQueue > 0 or currentPlayerCount >= MAX_QUEUE_SIZE do
                        local partyInfo = nextGroupInQueue[headIndex]

                        if not partyInfo then break end

                        if currentPlayerCount + #partyInfo.ids <= MAX_QUEUE_SIZE then
                            table.insert(playingParties, partyInfo)
                            currentPlayerCount += #partyInfo.ids
                            table.remove(nextGroupInQueue, headIndex)
                        else
                            headIndex += 1
                        end
                    end

                    debugPrint('obtained playing parties')

                    if currentPlayerCount < IDEAL_PLAYER_COUNT then
                        debugPrint('player count not ideal')

                        local averagePartyWeight = 0

                        for _,party in pairs(playingParties) do
                            averagePartyWeight += party.weight
                        end

                        averagePartyWeight /= #playingParties

                        debugPrint('average party weight', averagePartyWeight)

                        if averagePartyWeight < MAX_WEIGHT_PER_PARTY then
                            for _,party in pairs(playingParties) do
                                party.weight += 1
                            end

                            for _, partyInfo in pairs(playingParties) do
                                task.spawn(addToQueue, queue, partyInfo, 1) -- put back at the front of the queue
                            end

                            debugPrint('weight not sufficient, retrying')
                            abortCurrentQueue = true
                        end
                    end

                    if not abortCurrentQueue then
                        local temporaryTeams, playersNeeded = generateTeams(playingParties, currentPlayerCount)
                        if playersNeeded > 0 then -- try to find more players to make teams even
                            abortCurrentQueue, currentPlayerCount = getMorePartiesForTeams(queue, playingParties, playersNeeded, currentPlayerCount)
                        end
                    end

                    for _, partyInfo in pairs(nextGroupInQueue) do
                        task.spawn(addToQueue, queue, partyInfo, 1) -- put back at the front of the queue
                    end

                    if not abortCurrentQueue then
                        debugPrint('readded not playing parties at high priority')

                        local partyIdList = {}
                        local partyIdListCount = 0
                        local teams = nil

                        for _,partyInfo in pairs(playingParties) do
                            local tableIndex = table.concat(partyInfo.ids, "-").."-"..partyInfo.queueId

                            self.WaitingForValidation[tableIndex] = "waiting"
                            self.ForeignQueueStorage[partyInfo.serverId..partyInfo.queueId] = partyInfo

                            if partyInfo.serverId ~= SERVER_JOB_ID then
                                task.spawn(publishMessage, partyInfo.serverId, {
                                    action = "validate",
                                    serverId = SERVER_JOB_ID,
                                    queueId = partyInfo.queueId
                                })
                            else
                                debugPrint('in server validation')

                                sendMessageToPlayers(partyInfo.queueId, "validate")

                                local valid = validateParty(partyInfo.queueId)
                                if valid then
                                    self.WaitingForValidation[tableIndex] = "ready"
                                else
                                    self.WaitingForValidation[tableIndex] = "failed"
                                end
                            end

                            partyIdList[tableIndex] = partyInfo
                            partyIdListCount += 1
                        end

                        debugPrint('sent validation message to all parties')

                        if mmrBoxInfo.event == "Teams" or mmrBoxInfo.event == "Toy Factory" then
                            teams = generateTeams(partyIdList, currentPlayerCount)

                            for i,v in pairs(teams['1']) do
                                debugPrint(1,i,v)
                            end

                            for i,v in pairs(teams['2']) do
                                debugPrint(2,i,v)
                            end
                        end

                        debugPrint('generated teams (if applicable)')

                        task.spawn(function()
                            local maxWaitTime = tick() + MAX_VALIDATION_WAIT_TIME
                            local abortValidation = false

                            repeat
                                local validatedTotal = 0
                                local removeIndex = false

                                for id, partyInfo in pairs(partyIdList) do
                                    print(#partyIdList, id, self.WaitingForValidation[id])
                                    if self.WaitingForValidation[id] == "ready" then
                                        validatedTotal += 1
                                    elseif self.WaitingForValidation[id] == "failed" then
                                        debugPrint('failed validation, removing invalided party')
                                        removeIndex = id
                                        break
                                    end
                                end

                                if removeIndex ~= false then
                                    debugPrint('starting removal process')

                                    currentPlayerCount -= #partyIdList[removeIndex].ids

                                    partyIdList[removeIndex] = nil
                                    partyIdListCount -= 1

                                    if currentPlayerCount <= 1 then -- requeue last party and abort the validation process
                                        debugPrint('not enough players, requeueing the last person as a party')
                                        for _, partyInfo in pairs(partyIdList) do
                                            task.spawn(addToQueue, queue, partyInfo, 1)
                                        end

                                        abortValidation = true
                                    else
                                        debugPrint('rechecking teams')
                                        local temporaryTeams, playersNeeded = generateTeams(partyIdList, currentPlayerCount)
                                        if playersNeeded > 0 then -- try to find more players to make teams even
                                            for _, partyInfo in pairs(partyIdList) do
                                                task.spawn(addToQueue, queue, partyInfo, 1)
                                            end

                                            abortValidation = true -- currently if validation fails and teams are uneven, just give up and requeue them

                                            debugPrint('teams not sufficient, requeue the remaining parties')
                                        else
                                            teams = temporaryTeams -- update new team values
                                            debugPrint('✅ teams are now good')
                                        end
                                    end
                                end

                                debugPrint(validatedTotal.." / "..partyIdListCount)
                                task.wait(1)
                            until validatedTotal == partyIdListCount or currentPlayerCount == 0 or (tick() > maxWaitTime) or abortValidation

                            if not abortValidation then
                                if (tick() <= maxWaitTime) and currentPlayerCount > 0 then
                                    local reservedServer = TeleportService:ReserveServer(levelId)

                                    debugPrint('created reserved server')

                                    for id, partyInfo in pairs(partyIdList) do
                                        if partyInfo.serverId ~= SERVER_JOB_ID then
                                            task.spawn(publishMessage, partyInfo.serverId, {
                                                action = "join",
                                                reservedId = reservedServer,
                                                queueId = partyInfo.queueId,
                                                numPlayers = currentPlayerCount,
                                                teams = teams
                                            })
                                        else
                                            sendMessageToPlayers(partyInfo.queueId, "found")

                                            local playerList = {}
                                            for _,id in pairs(partyInfo.ids) do
                                                table.insert(playerList, Players:GetPlayerByUserId(id))
                                            end

                                            Teleport:QueueTeleport(playerList, reservedServer, currentPlayerCount, getBoxInfoForTeleport(queueNumber, teams))
                                        end
                                    end

                                    debugPrint('sent message for all parties to join')
                                    debugPrint('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
                                else
                                    for _, partyInfo in pairs(playingParties) do
                                        task.spawn(addToQueue, queue, partyInfo, 1) -- put back at the front of the queue
                                    end
                                end
                            else
                                for id, partyInfo in pairs(partyIdList) do
                                    if partyInfo.serverId ~= SERVER_JOB_ID then
                                        task.spawn(publishMessage, partyInfo.serverId, {
                                            action = "retry",
                                            queueId = partyInfo.queueId,
                                        })
                                    else
                                        sendMessageToPlayers(partyInfo.queueId, "retry")
                                    end
                                end
                            end
                        end)
                    end
                end
            end

            task.wait(5)
        end
    end)
end

--------------- Remotes ----------------
QueueRemote.OnServerEvent:Connect(function(client, action, args)
    if action == "leave" then
        QueueSystem:LeaveQueue(client.UserId, args.queueId)
    end
end)
return QueueSystem