local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

local rsSide = "right"
local openTime = 3

rednet.open("back")
rs.setAnalogOutput(rsSide, 15)

local cfg = {}
if fs.exists("door.cfg") then
    local f = fs.open("door.cfg", "r")
    cfg = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not cfg.serverID then
    print("enter server id:")
    cfg.serverID = tonumber(read())
    local f = fs.open("door.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

local srvID = cfg.serverID
local busy = false

term.clear()
term.setCursorPos(1,1)
print("door controller running")
print("server: " .. srvID)

while true do
    local sender, msg = rednet.receive("keycard_door")

    if sender == srvID and type(msg) == "table" and msg.type == "open" then
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
