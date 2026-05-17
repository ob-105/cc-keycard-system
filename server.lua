local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

rednet.open("back")

local netID = "1"
if fs.exists("net.cfg") then
    local f = fs.open("net.cfg", "r")
    local n = textutils.unserialize(f.readAll()) or {}
    f.close()
    if n.net and tostring(n.net) ~= "" then netID = tostring(n.net) end
end

local verifyProto = "keycard_verify_" .. netID
local responseProto = "keycard_response_" .. netID
local discProto = "keycard_disc_" .. netID
local lists = {approved = {}, banned = {}}

local function saveLists()
    local f = fs.open("keycard_lists.cfg", "w")
    f.write(textutils.serialize(lists))
    f.close()
end

if fs.exists("keycard_lists.cfg") then
    local f = fs.open("keycard_lists.cfg", "r")
    local d = textutils.unserialize(f.readAll())
    f.close()
    if type(d) == "table" then lists = d end
end

local function checkCard(cid, cname)
    for _, e in ipairs(lists.banned) do
        if e.id == cid or e.name == cname then
            return false, "banned" .. (e.reason and (": " .. e.reason) or ""), 0
        end
    end
    for _, e in ipairs(lists.approved) do
        if e.id == cid or e.name == cname then
            return true, "ok", tonumber(e.clearance) or 1
        end
    end
    return false, "not on list", 0
end

local function adminMenu()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("--- admin ---")
        print("1 approve card")
        print("2 ban card")
        print("3 remove approved")
        print("4 remove banned")
        print("5 view lists")
        print("6 back")
        local c = read()

        if c == "1" then
            print("id (blank to skip):")
            local id = tonumber(read())
            print("name (blank to skip):")
            local nm = read()
            if nm == "" then nm = nil end
            print("clearance level (default 1):")
            local cl = tonumber(read()) or 1
            table.insert(lists.approved, {id=id, name=nm, clearance=cl})
            saveLists()
            print("done")
            sleep(1)

        elseif c == "2" then
            print("id (blank to skip):")
            local id = tonumber(read())
            print("name (blank to skip):")
            local nm = read()
            if nm == "" then nm = nil end
            print("reason (optional):")
            local reason = read()
            if reason == "" then reason = nil end
            table.insert(lists.banned, {id=id, name=nm, reason=reason})
            saveLists()
            print("banned")
            sleep(1)

        elseif c == "3" then
            for i, e in ipairs(lists.approved) do
                print(i .. ". " .. tostring(e.id) .. " / " .. tostring(e.name))
            end
            print("remove which? (blank cancel)")
            local n = tonumber(read())
            if n and lists.approved[n] then
                table.remove(lists.approved, n)
                saveLists()
                print("removed")
            end
            sleep(1)

        elseif c == "4" then
            for i, e in ipairs(lists.banned) do
                print(i .. ". " .. tostring(e.id) .. " / " .. tostring(e.name))
            end
            print("remove which? (blank cancel)")
            local n = tonumber(read())
            if n and lists.banned[n] then
                table.remove(lists.banned, n)
                saveLists()
                print("removed")
            end
            sleep(1)

        elseif c == "5" then
            print("approved:")
            for _, e in ipairs(lists.approved) do
                print("  " .. tostring(e.id) .. " / " .. tostring(e.name) .. " (clr " .. tostring(e.clearance or 1) .. ")")
            end
            print("banned:")
            for _, e in ipairs(lists.banned) do
                print("  " .. tostring(e.id) .. " / " .. tostring(e.name) .. " (" .. tostring(e.reason) .. ")")
            end
            read()

        elseif c == "6" then
            break
        end
    end
end

term.clear()
term.setCursorPos(1,1)
print("server running (id: " .. os.computerID() .. ")")
print("network: " .. netID)
print("press A for admin")

local inAdmin = false

parallel.waitForAny(
    function()
        while true do
            if not inAdmin then
                local sender, msg, proto = rednet.receive(nil, 1)

                if sender and proto == discProto and type(msg) == "table" then
                    if msg.type == "who_server" and msg.net == netID then
                        rednet.send(sender, {type = "iam", role = "server", net = netID}, discProto)
                    end
                end

                if sender and proto == verifyProto and type(msg) == "table" and msg.type == "verify"
                    and type(msg.cardID) == "number" and type(msg.cardName) == "string"
                then
                    local minCl = tonumber(msg.minClearance) or 1
                    local allowed, reason, cardCl = checkCard(msg.cardID, msg.cardName)
                    local finalAllowed = allowed and (cardCl >= minCl)
                    if allowed and cardCl < minCl then
                        reason = "clearance too low (have " .. tostring(cardCl) .. ", need " .. tostring(minCl) .. ")"
                    end

                    print((finalAllowed and "granted" or "denied") .. ": " .. msg.cardName .. " scanner=" .. tostring(sender))

                    rednet.send(sender, {
                        allowed = finalAllowed,
                        reason = reason,
                        clearance = cardCl,
                        required = minCl
                    }, responseProto)
                end
            else
                sleep(0.1)
            end
        end
    end,
    function()
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.a and not inAdmin then
                inAdmin = true
                adminMenu()
                term.clear()
                term.setCursorPos(1,1)
                print("server running, press A for admin")
                inAdmin = false
            end
        end
    end,
    function()
        while true do
            sleep(30)
            if fs.exists("update.lua") then shell.run("update") end
        end
    end
)
