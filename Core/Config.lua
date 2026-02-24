-- AceDB-3.0 初始化、配置文件管理
local _, ns = ...

local AceDB3 = LibStub("AceDB-3.0")
local LibDualSpec = LibStub("LibDualSpec-1.0", true)
local DeepCopy = ns.DeepCopy
local MigrateOldData = ns.MigrateOldData

function ns:InitDB()
    local charKey = UnitName("player") .. " - " .. GetRealmName()

    local oldCharConfig = CDFlowDB_Char and CDFlowDB_Char.config and DeepCopy(CDFlowDB_Char.config)
    local oldProfiles = CDFlowDB_Profiles and next(CDFlowDB_Profiles) and DeepCopy(CDFlowDB_Profiles)
    local oldAccountConfig = nil
    if CDFlowDB and CDFlowDB.essential and not CDFlowDB.profiles then
        oldAccountConfig = DeepCopy(CDFlowDB)
        wipe(CDFlowDB)
    end

    local db = AceDB3:New("CDFlowDB", { profile = ns.defaults }, charKey)

    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(db, "CDFlow")
    end

    ns.acedb = db

    local migrated = false
    if oldCharConfig then
        MigrateOldData(oldCharConfig)
        for k, v in pairs(oldCharConfig) do
            if type(v) == "table" then
                db.profile[k] = DeepCopy(v)
            else
                db.profile[k] = v
            end
        end
        migrated = true
    elseif oldAccountConfig then
        MigrateOldData(oldAccountConfig)
        for k, v in pairs(oldAccountConfig) do
            if type(v) == "table" then
                db.profile[k] = DeepCopy(v)
            else
                db.profile[k] = v
            end
        end
        migrated = true
    end

    if oldProfiles then
        for name, cfg in pairs(oldProfiles) do
            MigrateOldData(cfg)
            db.sv.profiles[name] = cfg
        end
    end

    if migrated or oldProfiles then
        CDFlowDB_Char = nil
        CDFlowDB_Profiles = nil
    end

    ns.db = db.profile
end

function ns:OnProfileChanged()
    ns.db = ns.acedb.profile
end
