-- ============================================================
--  VERIFICATION SERVER  (Computer 2)
--  Install on: Any computer with a Wireless Modem.
--  No redstone connections needed.
--
--  First run: you will be prompted for the Door Controller's
--  computer ID. Saved to "server.cfg".
--
--  ADMIN INTERFACE:
--    Press [A] at any time to open the admin menu where you
--    can add/remove approved and banned cards.
-- ============================================================

local VERSION = "1.0.0"  -- managed by update.lua / manifest.json

-- ── Auto-update ───────────────────────────────────────────────
if fs.exists("update.lua") then shell.run("update") end

-- ── Configuration ────────────────────────────────────────────
local MODEM_SIDE        = "back"
local VERIFY_PROTOCOL   = "keycard_verify"
local RESPONSE_PROTOCOL = "keycard_response"
local DOOR_PROTOCOL     = "keycard_door"
local CONFIG_FILE       = "server.cfg"
local LISTS_FILE        = "keycard_lists.cfg"

-- ── Modem setup ──────────────────────────────────────────────
if not peripheral.isPresent(MODEM_SIDE) then
    error("No peripheral found on '" .. MODEM_SIDE .. "'. Attach a Wireless Modem.", 0)
end
rednet.open(MODEM_SIDE)

-- ── Config (door controller ID) ──────────────────────────────
local config = {}
if fs.exists(CONFIG_FILE) then
    local f = fs.open(CONFIG_FILE, "r")
    config = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not config.doorControllerID then
    print("=== SERVER FIRST-RUN SETUP ===")
    print("Enter the Door Controller's computer ID:")
    config.doorControllerID = tonumber(read())
    if not config.doorControllerID then error("Invalid door controller ID.", 0) end
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize(config))
    f.close()
    print("Saved.")
    sleep(1)
end

local DOOR_CONTROLLER_ID = config.doorControllerID

-- ── Lists ────────────────────────────────────────────────────
--  approved : { { id=number, name=string }, ... }
--  banned   : { { id=number, name=string, reason=string }, ... }

local lists = { approved = {}, banned = {} }

local function saveLists()
    local f = fs.open(LISTS_FILE, "w")
    f.write(textutils.serialize(lists))
    f.close()
end

local function loadLists()
    if fs.exists(LISTS_FILE) then
        local f = fs.open(LISTS_FILE, "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if type(data) == "table" then lists = data end
    end
end

loadLists()

-- ── Helpers ──────────────────────────────────────────────────
local function log(msg)
    print("[" .. os.date("%H:%M:%S") .. "] " .. msg)
end

-- Returns allowed (bool), reason (string)
local function verify(cardID, cardName)
    -- Banned check first — takes priority
    for _, entry in ipairs(lists.banned) do
        if entry.id == cardID or entry.name == cardName then
            return false, "Banned: " .. (entry.reason or "no reason given")
        end
    end
    -- Approved check
    for _, entry in ipairs(lists.approved) do
        if entry.id == cardID or entry.name == cardName then
            return true, "Approved"
        end
    end
    return false, "Not on approved list"
end

-- ── Admin menu ───────────────────────────────────────────────
local function promptID(prompt)
    print(prompt .. " (leave blank to skip):")
    local raw = read()
    if raw == "" then return nil end
    return tonumber(raw)
end

local function promptStr(prompt)
    print(prompt .. " (leave blank to skip):")
    local val = read()
    if val == "" then return nil end
    return val
end

local function adminMenu()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("╔══════════════════════════╗")
        print("║     ADMIN MENU           ║")
        print("╠══════════════════════════╣")
        print("║ 1. Approve a card        ║")
        print("║ 2. Ban a card            ║")
        print("║ 3. Remove from approved  ║")
        print("║ 4. Remove from banned    ║")
        print("║ 5. View lists            ║")
        print("║ 6. Exit admin menu       ║")
        print("╚══════════════════════════╝")
        local choice = read()

        if choice == "1" then
            local id   = promptID("Card computer ID")
            local name = promptStr("Card computer label/name")
            if not id and not name then
                print("At least one of ID or name required.")
            else
                table.insert(lists.approved, { id = id, name = name })
                saveLists()
                print("Added to approved list.")
            end
            sleep(1.5)

        elseif choice == "2" then
            local id     = promptID("Card computer ID")
            local name   = promptStr("Card computer label/name")
            local reason = promptStr("Ban reason")
            if not id and not name then
                print("At least one of ID or name required.")
            else
                table.insert(lists.banned, { id = id, name = name, reason = reason })
                saveLists()
                print("Added to banned list.")
            end
            sleep(1.5)

        elseif choice == "3" then
            if #lists.approved == 0 then
                print("Approved list is empty.")
                sleep(1.5)
            else
                print("=== APPROVED ===")
                for i, e in ipairs(lists.approved) do
                    print(i .. ". ID=" .. tostring(e.id) .. "  Name=" .. tostring(e.name))
                end
                print("Enter number to remove (blank to cancel):")
                local n = tonumber(read())
                if n and lists.approved[n] then
                    table.remove(lists.approved, n)
                    saveLists()
                    print("Removed.")
                end
                sleep(1.5)
            end

        elseif choice == "4" then
            if #lists.banned == 0 then
                print("Banned list is empty.")
                sleep(1.5)
            else
                print("=== BANNED ===")
                for i, e in ipairs(lists.banned) do
                    print(i .. ". ID=" .. tostring(e.id) ..
                          "  Name=" .. tostring(e.name) ..
                          "  Reason=" .. tostring(e.reason))
                end
                print("Enter number to remove (blank to cancel):")
                local n = tonumber(read())
                if n and lists.banned[n] then
                    table.remove(lists.banned, n)
                    saveLists()
                    print("Removed.")
                end
                sleep(1.5)
            end

        elseif choice == "5" then
            print("=== APPROVED (" .. #lists.approved .. ") ===")
            for _, e in ipairs(lists.approved) do
                print("  ID=" .. tostring(e.id) .. "  Name=" .. tostring(e.name))
            end
            print("=== BANNED (" .. #lists.banned .. ") ===")
            for _, e in ipairs(lists.banned) do
                print("  ID=" .. tostring(e.id) ..
                      "  Name=" .. tostring(e.name) ..
                      "  Reason=" .. tostring(e.reason))
            end
            print("Press Enter to continue.")
            read()

        elseif choice == "6" then
            term.clear()
            term.setCursorPos(1, 1)
            log("Returned to server mode. Press [A] for admin.")
            break
        end
    end
end

-- ── Main (parallel: network + admin key listener) ────────────
term.clear()
term.setCursorPos(1, 1)
log("Verification Server active  (ID: " .. os.computerID() .. ")")
log("Door Controller ID : " .. DOOR_CONTROLLER_ID)
log("Approved entries   : " .. #lists.approved)
log("Banned entries     : " .. #lists.banned)
log("Press [A] to open admin menu.")

-- Flag shared between the two parallel threads
local inAdmin = false

parallel.waitForAny(

    -- Thread 1: handle incoming verification requests
    function()
        while true do
            if not inAdmin then
                local senderID, message = rednet.receive(VERIFY_PROTOCOL, 1)

                if senderID and type(message) == "table"
                   and message.type == "verify"
                   and type(message.cardID)   == "number"
                   and type(message.cardName) == "string"
                then
                    local cardID   = message.cardID
                    local cardName = message.cardName

                    log("Request from scanner " .. senderID ..
                        " -> ID=" .. cardID .. "  Name=" .. cardName)

                    local allowed, reason = verify(cardID, cardName)

                    -- Reply to scanner
                    rednet.send(senderID, {
                        allowed = allowed,
                        reason  = reason,
                    }, RESPONSE_PROTOCOL)

                    -- If allowed, also notify the door controller
                    if allowed then
                        rednet.send(DOOR_CONTROLLER_ID, {
                            type     = "open",
                            cardID   = cardID,
                            cardName = cardName,
                        }, DOOR_PROTOCOL)
                        log("GRANTED: " .. cardName .. " -> door controller notified.")
                    else
                        log("DENIED : " .. cardName .. " (" .. reason .. ")")
                    end
                end
            else
                sleep(0.1)
            end
        end
    end,

    -- Thread 2: watch for [A] keypress to enter admin mode
    function()
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.a and not inAdmin then
                inAdmin = true
                sleep(0.1)   -- let network thread finish any in-flight receive
                adminMenu()
                inAdmin = false
            end
        end
    end
)
