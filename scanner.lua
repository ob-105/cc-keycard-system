local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

local rsSide = "right"
local openTime = 3

rednet.open("back")
rs.setAnalogOutput(rsSide, 15)

local cfg = {}
if fs.exists("scanner.cfg") then
    local f = fs.open("scanner.cfg", "r")
    cfg = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not cfg.serverID then
    print("first time setup")
    print("enter server computer id:")
    cfg.serverID = tonumber(read())
    local f = fs.open("scanner.cfg", "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

local srvID = cfg.serverID
local cooldowns = {}

term.clear()
term.setCursorPos(1,1)
print("scanner running, server: " .. srvID)

while true do
    local sender, msg = rednet.receive("keycard_ping", 2)

    if sender and type(msg) == "table" and type(msg.id) == "number" then
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
            }, "keycard_verify")

            local rs2, resp = rednet.receive("keycard_response", 5)

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
