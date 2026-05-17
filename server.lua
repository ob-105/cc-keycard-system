local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

rednet.open("back")

local cfg = {}
if fs.exists("server.cfg") then
    local f = fs.open("server.cfg", "r")
    cfg = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not cfg.doorID then
    print("enter door controller id:")
    cfg.doorID = tonumber(read())
    local f = fs.open("server.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

local doorID = cfg.doorID
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
            return false, "banned" .. (e.reason and (": " .. e.reason) or "")
        end
    end
    for _, e in ipairs(lists.approved) do
        if e.id == cid or e.name == cname then
            return true, "ok"
        end
    end
    return false, "not on list"
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
            table.insert(lists.approved, {id=id, name=nm})
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
                print("  " .. tostring(e.id) .. " / " .. tostring(e.name))
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
print("door controller: " .. doorID)
print("press A for admin")

local inAdmin = false

parallel.waitForAny(
    function()
        while true do
            if not inAdmin then
                local sender, msg = rednet.receive("keycard_verify", 1)
                if sender and type(msg) == "table" and msg.type == "verify"
                    and type(msg.cardID) == "number" and type(msg.cardName) == "string"
                then
                    local allowed, reason = checkCard(msg.cardID, msg.cardName)
                    print((allowed and "granted" or "denied") .. ": " .. msg.cardName)

                    rednet.send(sender, {allowed=allowed, reason=reason}, "keycard_response")

                    if allowed then
                        rednet.send(doorID, {
                            type="open",
                            cardID=msg.cardID,
                            cardName=msg.cardName
                        }, "keycard_door")
                    end
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
    end
)
