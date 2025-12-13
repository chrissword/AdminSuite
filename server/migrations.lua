AS = AS or {}
AS.Migrations = AS.Migrations or {}

local DB     = AS.DB
local Tables = AS.Tables
local Utils  = AS.Utils

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------

local function info(msg, ...)
    if Utils and Utils.Info then
        Utils.Info(msg, ...)
    else
        print(('[AdminSuite:MIGRATIONS] ' .. msg):format(...))
    end
end

local function warn(msg, ...)
    if Utils and Utils.Warn then
        Utils.Warn(msg, ...)
    else
        print(('[AdminSuite:MIGRATIONS:WARN] ' .. msg):format(...))
    end
end

-- Resolve table names from shared/tables.lua with sane fallbacks.
local function resolveTables()
    local t = {}

    t.Bans       = (Tables and Tables.Bans)       or 'bans'
    t.Reports    = (Tables and Tables.Reports)    or 'as_reports'
    t.Audit      = (Tables and Tables.Audit)      or 'as_audit'
    t.Characters = (Tables and Tables.Characters) or nil
    t.Vehicles   = (Tables and Tables.Vehicles)   or nil

    -- NEW TABLE NAME (added to table registry later)
    t.Discipline = 'adminsuite_discipline'

    if t.Bans ~= 'bans' then
        warn('Bans table is mapped to %s (expected `bans` for QBCore compatibility)', t.Bans)
    end

    return t
end

---------------------------------------------------------------------
-- Column helpers
---------------------------------------------------------------------

local function columnExists(tableName, columnName)
    local ok, result = pcall(function()
        return DB.scalar(
            ([[SHOW COLUMNS FROM `%s` LIKE '%s';]]):format(tableName, columnName),
            {}
        )
    end)

    if not ok then
        warn('Column check failed for %s.%s (%s)', tableName, columnName, tostring(result))
        return false
    end

    return result ~= nil
end

local function ensureBanExtensions(tableName)
    local function addColumnIfMissing(colName, ddl)
        if not columnExists(tableName, colName) then
            DB.execute(([[ALTER TABLE `%s` ADD COLUMN %s;]]):format(tableName, ddl))
            info('Added column `%s` to `%s`', colName, tableName)
        end
    end

    addColumnIfMissing('actor_identifier',  '`actor_identifier`  VARCHAR(128) NULL')
    addColumnIfMissing('target_identifier', '`target_identifier` VARCHAR(128) NULL')
    addColumnIfMissing('duration_seconds',  '`duration_seconds`  INT(11) NOT NULL DEFAULT 0')
    addColumnIfMissing('expires_at',        '`expires_at`        DATETIME NULL')
    addColumnIfMissing('revoked_at',        '`revoked_at`        DATETIME NULL')
end

local function ensureDisciplineStatusColumn(tableName)
    if not columnExists(tableName, 'status') then
        DB.execute(([[ALTER TABLE `%s`
            ADD COLUMN `status` VARCHAR(64) NOT NULL DEFAULT '';
        ]]):format(tableName))
        info('Added column `status` to discipline table (%s)', tableName)
    end
end

---------------------------------------------------------------------
-- Table creation
---------------------------------------------------------------------

local function createBans(tnames)
    local tableName = tnames.Bans

    local sql = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id`       INT(11)      NOT NULL AUTO_INCREMENT,
            `name`     VARCHAR(50)  DEFAULT NULL,
            `license`  VARCHAR(50)  DEFAULT NULL,
            `discord`  VARCHAR(50)  DEFAULT NULL,
            `ip`       VARCHAR(50)  DEFAULT NULL,
            `reason`   TEXT         DEFAULT NULL,
            `expire`   INT(11)      DEFAULT NULL,
            `bannedby` VARCHAR(255) NOT NULL DEFAULT 'AdminSuite',

            `actor_identifier`  VARCHAR(128) NULL,
            `target_identifier` VARCHAR(128) NULL,
            `duration_seconds`  INT(11) NOT NULL DEFAULT 0,
            `expires_at`        DATETIME NULL,
            `revoked_at`        DATETIME NULL,

            PRIMARY KEY (`id`),
            KEY `license` (`license`),
            KEY `discord` (`discord`),
            KEY `ip` (`ip`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName)

    DB.execute(sql)
    ensureBanExtensions(tableName)
    info('Ensured bans table exists (QBCore + AdminSuite columns) [%s]', tableName)
end

local function createReports(tnames)
    local tableName = tnames.Reports
    local sql = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
            reporter_identifier VARCHAR(128) NOT NULL,
            target_identifier   VARCHAR(128) NULL,
            status              VARCHAR(32)  NOT NULL DEFAULT 'open',
            category            VARCHAR(64)  NULL,
            message             TEXT         NOT NULL,
            claimed_by          VARCHAR(128) NULL,
            created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at          TIMESTAMP    NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
            metadata            JSON         NULL,
            PRIMARY KEY (id),
            KEY idx_status (status),
            KEY idx_claimed_by (claimed_by)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName)

    DB.execute(sql)
    info('Ensured reports table exists (%s)', tableName)
end

local function createAudit(tnames)
    local tableName = tnames.Audit
    local sql = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            actor_identifier  VARCHAR(128) NOT NULL,
            target_identifier VARCHAR(128) NULL,
            event_name        VARCHAR(128) NOT NULL,
            payload           JSON         NULL,
            created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_actor  (actor_identifier),
            KEY idx_target (target_identifier),
            KEY idx_event  (event_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName)

    DB.execute(sql)
    info('Ensured audit table exists (%s)', tableName)
end

---------------------------------------------------------------------
-- NEW: Discipline Table
---------------------------------------------------------------------

local function createDiscipline(tnames)
    local tableName = tnames.Discipline or 'adminsuite_discipline'

    local sql = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            staff_name       VARCHAR(100)    NOT NULL,
            staff_identifier VARCHAR(128)    NOT NULL,
            target_name      VARCHAR(100)    NOT NULL,
            target_cid       VARCHAR(64)     NULL,
            target_license   VARCHAR(64)     NULL,
            reason           TEXT            NOT NULL,
            status           VARCHAR(64)     NOT NULL DEFAULT '',
            notes            TEXT            NULL,
            created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

            PRIMARY KEY (id),
            KEY idx_staff          (staff_identifier),
            KEY idx_target_license (target_license),
            KEY idx_created_at     (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName)

    DB.execute(sql)
    ensureDisciplineStatusColumn(tableName)

    info('Ensured discipline table exists (%s)', tableName)
end

---------------------------------------------------------------------
-- External table sanity checks
---------------------------------------------------------------------

local function checkExternalTable(name)
    if not name or name == '' then return end

    local ok = pcall(function()
        DB.scalar(('SELECT 1 FROM `%s` LIMIT 1;'):format(name), {})
    end)

    if not ok then
        warn('External table `%s` may not exist or is inaccessible', name)
    else
        info('Verified external table `%s`', name)
    end
end

---------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------

function AS.Migrations.RunAll()
    info('Running AdminSuite migrations...')

    local tnames = resolveTables()

    createBans(tnames)
    createReports(tnames)
    createAudit(tnames)

    -- NEW
    createDiscipline(tnames)

    if tnames.Characters then
        checkExternalTable(tnames.Characters)
    end
    if tnames.Vehicles then
        checkExternalTable(tnames.Vehicles)
    end

    info('AdminSuite migrations complete.')
end
