--
-- actions/fastbuild/fastbuild.lua
-- Extend the existing exporters with support for FASTBuild
-- Copyright (c) 2017-2017 Daniel Penkała 
--

    local p = premake
    p.fastbuild.utils = { }

    local fbuild = p.fastbuild
    local utils = fbuild.utils

---
-- Define the FASTBuild utility constants
---
    utils.constants = { }
    utils.constants.section = { }
    utils.constants.section.name = "// %s"
    utils.constants.section.separator = "//---------------------------------------------------------------------------"

---
-- Define the FASTBuild utility functions
---
    function utils.separator()
        p.x(utils.constants.section.separator)
    end

    function utils.section(str, ...) 
        local formated = str:format(...)
        p.x(utils.constants.section.name, formated)
        utils.separator()
    end

    function utils.struct_begin(name, ...)
        p.x(".%s = ", name:format(...))
        p.push("[")
    end

    function utils.struct_pair(key, value, ...)
        if type(value) == "string" then 
            if #({...}) == 0 then 
                p.x(".%s = '%s'", key, value)
            else
                p.x(".%s = '%s'", key, value:format(...))
            end
        else 
            p.x(".%s = {", key)
            p.push()
            for _, val in pairs(value) do 
                p.x("'%s',", val)
            end
            p.pop("}")
        end
    end

    function utils.struct_pair_append(value, ...)
        if #({...}) == 0 then 
            p.x("    + '%s'", value)
        else
            p.x("    + '%s'", value:format(...))
        end
    end

    function fbuild.struct_pair_append(value, ...)
        if #({...}) == 0 then 
            p.x("    + %s", value)
        else
            p.x("    + %s", value:format(...))
        end
    end

    function utils.struct_end()
        p.pop("]")
        p.w()
    end

    function utils.struct(name, fields)
        utils.struct_begin(name)
        for _, field in pairs(fields) do 
            local name = field[1]
            
            if type(field[2]) == "string" then
                local value = field[2]:format(field[3], field[4], field[5], field[6])
                utils.struct_pair(name, value)

            else
                local value = field[2]
                utils.struct_pair(name, value[1])
                for i = 2, #value do 
                    utils.struct_pair_append(value[i])
                end
            end
        end
        utils.struct_end()
    end

---------------------------------------------------------------------------
--
-- Naming utils 
--
---------------------------------------------------------------------------

--- 
-- Returns the target platform name for the given config
---
    function fbuild.targetPlatform(cfg)
        local config = cfg.config or cfg
        return config.system .. "|" .. config.architecture
    end

---
-- Returns the fbuild name for the platform structure to be used for ObjectList and Library functions 
--- 
    function fbuild.targetPlatformStruct(cfg)
        local config = cfg.config or cfg
        return table.concat({ "platform", cfg.system, cfg.architecture }, "_")
    end


---------------------------------------------------------------------------
--
-- Generation utils 
--
---------------------------------------------------------------------------

---
-- Prints an include statement with the given path
---
    function fbuild.include(path) 
        p.x('#include "%s"', path)
    end
