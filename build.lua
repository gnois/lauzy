-- Build script: bundles all Lua modules into one dependency-free
-- bin/lau.zy bytecode file (LuaJIT string.dump output).

local OUTPUT_BIN = "bin/lau.zy"              -- final self-contained executable
local MODULE_GROUPS = {                      -- folders whose *.lua become modules
    {dir = "lau", prefix = "lau", extension = ".lua"},
}
local EXTRA_MODULES = {                      -- extra top-level modules
    {path = "term.lua", name = "term"},
}

local ENTRY_LUA = "lau.lua"                  -- entry point run by the launcher

-- Quote a path so it survives being passed to the shell.
local function quote_arg(path)
    return string.format("%q", path)
end

-- List the files in a directory (works with both cmd and sh).
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

-- Chunk name used in errors/tracebacks for a compiled module.
local function chunk_name(path)
    return "@" .. path:gsub("\\", "/")
end

-- Compile one module to bytecode and register it in package.preload.
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

-- Register every matching file of a module group.
local function add_module_group(lines, stats, group)
    for _, file in ipairs(list_files(group.dir)) do
        if file:sub(-#group.extension) == group.extension then
            local stem = file:sub(1, #file - #group.extension)
            add_module(lines, stats, group.prefix .. "." .. stem, group.dir .. "/" .. file)
        end
    end
end

-- Accumulated Lua source lines that make up the generated launcher:
-- one package.preload line per module, then the entry point call.
local bootstrap = {}
local stats = {modules = 0}

-- Preload the extra modules, then every module group.
for _, module in ipairs(EXTRA_MODULES) do
    add_module(bootstrap, stats, module.name, module.path)
end

for _, group in ipairs(MODULE_GROUPS) do
    add_module_group(bootstrap, stats, group)
end

-- Compile the entry point and append the call that runs it.
local main_chunk = assert(loadfile(ENTRY_LUA))
local main_bytecode = string.dump(main_chunk)
bootstrap[#bootstrap + 1] = string.format(
    "return assert(loadstring(%q, %q))(...)\n",
    main_bytecode,
    chunk_name(ENTRY_LUA)
)

-- Compile the launcher and dump it as the final bytecode file.
local launcher = assert(loadstring(table.concat(bootstrap), chunk_name(OUTPUT_BIN)))
local out = assert(io.open(OUTPUT_BIN, "wb"), "could not create " .. OUTPUT_BIN)
out:write(string.dump(launcher))
out:close()

print(string.format("built %s with %d Lua modules", OUTPUT_BIN, stats.modules))
