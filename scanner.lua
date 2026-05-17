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

local pingProto = "keycard_ping_" .. netID
local verifyProto = "keycard_verify_" .. netID
local responseProto = "keycard_response_" .. netID
local discProto = "keycard_disc_" .. netID

rednet.open("back")
rs.setAnalogOutput(rsSide, 15)

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
    local f = fs.open("scanner.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
    print("found server id: " .. tostring(cfg.serverID))
end

local srvID = cfg.serverID
local cooldowns = {}

term.clear()
term.setCursorPos(1,1)
print("scanner running, server: " .. srvID)
print("network: " .. netID)

while true do
    local sender, msg, proto = rednet.receive(nil, 2)

    if sender and proto == pingProto and type(msg) == "table" and type(msg.id) == "number" then
        local cid = msg.id
        local cname = msg.name

        local cd = cooldowns[cid]
        if not cd or os.clock() >= cd then
            print("card detected: " .. cname .. " (" .. cid .. ")")

            rednet.send(srvID, {
                type = "verify",
                cardID = cid,
                cardName = cname,
                scannerID = os.computerID()
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
