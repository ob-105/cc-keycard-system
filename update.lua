-- ============================================================
--  AUTO-UPDATER
--  File: update.lua
--  Run this (or let each main script run it) to pull the
--  latest versions of all scripts from GitHub.
--  Repository: https://github.com/ob-105/cc-keycard-system
-- ============================================================

local GITHUB_USER  = "ob-105"
local GITHUB_REPO  = "cc-keycard-system"
local BRANCH       = "main"
local BASE_URL     = "https://raw.githubusercontent.com/"
                   .. GITHUB_USER .. "/" .. GITHUB_REPO
                   .. "/" .. BRANCH .. "/"
local VERSION_FILE = ".cc_version"   -- local version cache

-- ── Helpers ──────────────────────────────────────────────────
local function log(msg)
    print("[Updater] " .. msg)
end

if not http then
    log("HTTP API is disabled. Enable it in the CC config.")
    return false
end

local function fetch(path)
    local ok, response = pcall(http.get, BASE_URL .. path)
    if not ok or not response then return nil end
    local body = response.readAll()
    response.close()
    if body == "" then return nil end
    return body
end

-- ── Read local version ────────────────────────────────────────
local localVersion = "none"
if fs.exists(VERSION_FILE) then
    local f = fs.open(VERSION_FILE, "r")
    localVersion = f.readLine() or "none"
    f.close()
end

-- ── Fetch remote manifest ─────────────────────────────────────
log("Checking for updates...")
local manifestStr = fetch("manifest.json")
if not manifestStr then
    log("Could not reach GitHub. Running offline.")
    return false
end

local manifest = textutils.unserializeJSON(manifestStr)
if not manifest or type(manifest.version) ~= "string" then
    log("Manifest parse error. Skipping update.")
    return false
end

local remoteVersion = manifest.version
log("Local: " .. localVersion .. "  |  Remote: " .. remoteVersion)

if localVersion == remoteVersion then
    log("Already up to date.")
    return false
end

-- ── Download updated files ────────────────────────────────────
log("Update available! Downloading v" .. remoteVersion .. "...")
local failed = {}

for _, filename in ipairs(manifest.files) do
    local content = fetch(filename)
    if content then
        local f = fs.open(filename, "w")
        f.write(content)
        f.close()
        log("  Updated: " .. filename)
    else
        log("  FAILED : " .. filename)
        table.insert(failed, filename)
    end
end

if #failed > 0 then
    log("WARNING: " .. #failed .. " file(s) failed to download.")
    log("Update aborted — version not saved to avoid partial state.")
    return false
end

-- ── Save new version & reboot ─────────────────────────────────
local f = fs.open(VERSION_FILE, "w")
f.write(remoteVersion)
f.close()

log("All files updated to v" .. remoteVersion .. ". Rebooting...")
sleep(1.5)
os.reboot()
