local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

local rsSide = "right"
local openTime = 3

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

local function netNum(s)
    local n = tonumber(s)
    if n then return math.floor(math.abs(n)) end
    local h = 0
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 1000
    end
    return h
end

local pingChannel = 43000 + (netNum(netID) % 1000)

rednet.open("back")
rs.setAnalogOutput(rsSide, 15)

local modem = peripheral.wrap("back")
if not modem then
    error("no modem on back", 0)
end
modem.open(pingChannel)

local cfg = {}
if fs.exists("scanner.cfg") then
    local f = fs.open("scanner.cfg", "r")
    cfg = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not cfg.serverID then
    print("finding server on network " .. netID .. "...")

    local found = nil
    local t = os.startTimer(0.1)
    while not found do
        local ev, a, b, c = os.pullEvent()
        if ev == "timer" and a == t then
            rednet.broadcast({type = "who_server", net = netID}, discProto)
            t = os.startTimer(1.2)
        elseif ev == "rednet_message" and c == discProto and type(b) == "table" then
            if b.type == "iam" and b.role == "server" and b.net == netID then
                found = a
            end
        end
    end

    cfg.serverID = found
    if not cfg.minClearance then cfg.minClearance = 1 end
    local f = fs.open("scanner.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
    print("found server id: " .. tostring(cfg.serverID))
end

if not cfg.minClearance then
    print("minimum clearance for this scanner? (default 1)")
    local n = tonumber(read())
    cfg.minClearance = n or 1
    local f = fs.open("scanner.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

local srvID = cfg.serverID
local minClearance = tonumber(cfg.minClearance) or 1
local cooldowns = {}

term.clear()
term.setCursorPos(1,1)
print("scanner running, server: " .. srvID)
print("network: " .. netID)
print("chan: " .. pingChannel)
print("min clearance: " .. tostring(minClearance))

parallel.waitForAny(
    function()
        while true do
            local ev, side, ch, rch, msg, dist = os.pullEvent("modem_message")

            if ch == pingChannel and type(msg) == "table" and type(msg.id) == "number" then
                local cid = msg.id
                local cname = tostring(msg.name or ("card-" .. tostring(cid)))

                if type(dist) == "number" and dist <= 3 then
                    local cd = cooldowns[cid]
                    if not cd or os.clock() >= cd then
                        print("card detected: " .. cname .. " (" .. cid .. ") d=" .. string.format("%.2f", dist))

                        rednet.send(srvID, {
                            type = "verify",
                            cardID = cid,
                            cardName = cname,
                            scannerID = os.computerID(),
                            minClearance = minClearance
                        }, verifyProto)

                        local rs2, resp = rednet.receive(responseProto, 5)

                        if rs2 == srvID and type(resp) == "table" then
                            if resp.allowed then
                                cooldowns[cid] = os.clock() + openTime + 1
                                print("granted: " .. cname)
                                rs.setAnalogOutput(rsSide, 0)
                                sleep(openTime)
                                rs.setAnalogOutput(rsSide, 15)
                                print("door closed")
                            else
                                print("denied: " .. cname .. " - " .. tostring(resp.reason))
                            end
                        else
                            print("no response from server")
                        end
                    end
                end
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
