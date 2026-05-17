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

local doorProto = "keycard_door_" .. netID
local discProto = "keycard_disc_" .. netID

rednet.open("back")
rs.setAnalogOutput(rsSide, 15)

local cfg = {}
if fs.exists("door.cfg") then
    local f = fs.open("door.cfg", "r")
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
            rednet.broadcast({type = "iam", role = "door", net = netID}, discProto)
            t = os.startTimer(1.2)
        elseif ev == "rednet_message" and c == discProto and type(b) == "table" then
            if b.type == "iam" and b.role == "server" and b.net == netID then
                found = a
            elseif b.type == "who_door" and b.net == netID then
                rednet.send(a, {type = "iam", role = "door", net = netID}, discProto)
            end
        end
    end

    cfg.serverID = found
    local f = fs.open("door.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
    print("found server id: " .. tostring(cfg.serverID))
end

local srvID = cfg.serverID
local busy = false

term.clear()
term.setCursorPos(1,1)
print("door controller running")
print("server: " .. srvID)
print("network: " .. netID)

while true do
    local sender, msg, proto = rednet.receive(nil)

    if sender and proto == discProto and type(msg) == "table" then
        if msg.type == "who_door" and msg.net == netID then
            rednet.send(sender, {type = "iam", role = "door", net = netID}, discProto)
        elseif msg.type == "who_server" and msg.net == netID then
            rednet.send(sender, {type = "iam", role = "door", net = netID}, discProto)
        end
    end

    if sender == srvID and proto == doorProto and type(msg) == "table" and msg.type == "open" then
        if not busy then
            busy = true
            print("opening for " .. tostring(msg.cardName))
            rs.setAnalogOutput(rsSide, 0)
            sleep(openTime)
            rs.setAnalogOutput(rsSide, 15)
            print("closed")
            busy = false
        end
    else
        print("ignored msg from " .. tostring(sender))
    end
end
