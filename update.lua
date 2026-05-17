local baseURL = "https://raw.githubusercontent.com/ob-105/cc-keycard-system/main/"

if not http then
    print("http disabled, skipping update")
    return false
end

local function fetch(path)
    local ok, res = pcall(http.get, baseURL .. path)
    if not ok or not res then return nil end
    local body = res.readAll()
    res.close()
    if body == "" then return nil end
    return body
end

local localVer = "none"
if fs.exists(".cc_version") then
    local f = fs.open(".cc_version", "r")
    localVer = f.readLine() or "none"
    f.close()
end

print("checking for updates...")
local raw = fetch("manifest.json")
if not raw then
    print("cant reach github, skipping")
    return false
end

local manifest = textutils.unserializeJSON(raw)
if not manifest then
    print("bad manifest")
    return false
end

if localVer == manifest.version then
    print("up to date (" .. localVer .. ")")
    return false
end

print("updating to " .. manifest.version .. "...")
local failed = {}

for _, fname in ipairs(manifest.files) do
    local content = fetch(fname)
    if content then
        local f = fs.open(fname, "w")
        f.write(content)
        f.close()
        print("  got " .. fname)
    else
        print("  failed: " .. fname)
        table.insert(failed, fname)
    end
end

if #failed > 0 then
    print("update incomplete, not saving version")
    return false
end

local f = fs.open(".cc_version", "w")
f.write(manifest.version)
f.close()

print("done, rebooting")
sleep(1)
os.reboot()
