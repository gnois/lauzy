local OUTPUT_BIN = "bin/lau.zy"
local MODULE_GROUPS = {
    {dir = "lau", prefix = "lau", extension = ".lua"},
}
local EXTRA_MODULES = {
    {path = "term.lua", name = "term"},
}

local ENTRY_LUA = "lau.lua"

local function quote_arg(path)
    return string.format("%q", path)
end

local function list_files(dir)
    local slash = package.config:sub(1, 1)
    local command
    if slash == "\\" then
        command = "dir /b /a:-d " .. quote_arg(dir:gsub("/", "\\"))
    else
        command = "ls -1 " .. quote_arg(dir)
    end
    local pipe = assert(io.popen(command), "failed to list files in " .. dir)
    local files = {}
    for file in pipe:lines() do
        files[#files + 1] = file
    end
    pipe:close()
    table.sort(files)
    return files
end

local function read_file(path, mode)
    local file, err = io.open(path, mode or "rb")
    if not file then
        error(err)
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function chunk_name(path)
    return "@" .. path:gsub("\\", "/")
end

local function add_module(lines, stats, modname, path)
    local chunk = assert(loadfile(path))
    local bytecode = string.dump(chunk)
    lines[#lines + 1] = string.format(
        "package.preload[%q] = assert(loadstring(%q, %q))\n",
        modname,
        bytecode,
        chunk_name(path)
    )
    stats.modules = stats.modules + 1
end

local function add_module_group(lines, stats, group)
    for _, file in ipairs(list_files(group.dir)) do
        if file:sub(-#group.extension) == group.extension then
            local stem = file:sub(1, #file - #group.extension)
            add_module(lines, stats, group.prefix .. "." .. stem, group.dir .. "/" .. file)
        end
    end
end


local bootstrap = {}
local stats = {modules = 0, sources = 0}

bootstrap[#bootstrap + 1] = "local embedded_files = {}\n"
bootstrap[#bootstrap + 1] = [[
local original_open = io.open
local function normalize_path(path)
    path = path:gsub("\\", "/")
    path = path:gsub("^%./+", "")
    path = path:gsub("^/+", "")
    return path
end
local function open_embedded(content)
    local offset = 1
    return {
        read = function(_, format)
            if format == nil or format == "*l" then
                if offset > #content then
                    return nil
                end
                local start_pos, end_pos = content:find("\r?\n", offset)
                if start_pos then
                    local line = content:sub(offset, start_pos - 1)
                    offset = end_pos + 1
                    return line
                end
                local tail = content:sub(offset)
                offset = #content + 1
                return tail
            end
            if format == "*a" then
                local tail = content:sub(offset)
                offset = #content + 1
                return tail
            end
            if type(format) == "number" then
                if offset > #content then
                    return nil
                end
                local chunk = content:sub(offset, offset + format - 1)
                offset = offset + #chunk
                if #chunk == 0 then
                    return nil
                end
                return chunk
            end
            error("unsupported embedded read format: " .. tostring(format))
        end,
        close = function()
            return true
        end,
    }
end
io.open = function(path, mode)
    local file = original_open(path, mode)
    if file or type(path) ~= "string" then
        return file
    end
    if mode and not mode:match("^r") then
        return file
    end
    local embedded = embedded_files[normalize_path(path)]
    if embedded ~= nil then
        return open_embedded(embedded)
    end
    return file
end
]]

for _, module in ipairs(EXTRA_MODULES) do
    add_module(bootstrap, stats, module.name, module.path)
end

for _, group in ipairs(MODULE_GROUPS) do
    add_module_group(bootstrap, stats, group)
end

local main_chunk = assert(loadfile(ENTRY_LUA))
local main_bytecode = string.dump(main_chunk)
bootstrap[#bootstrap + 1] = string.format(
    "return assert(loadstring(%q, %q))(...)\n",
    main_bytecode,
    chunk_name(ENTRY_LUA)
)

local launcher = assert(loadstring(table.concat(bootstrap), chunk_name(OUTPUT_BIN)))
local out = assert(io.open(OUTPUT_BIN, "wb"), "could not create " .. OUTPUT_BIN)
out:write(string.dump(launcher))
out:close()

print(string.format(
    "built %s with %d Lua modules",
    OUTPUT_BIN,
    stats.modules,
    stats.sources
))
