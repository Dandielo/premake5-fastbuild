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

    function fbuild.call(func, ...)
        local args = { ... }
        return function()
            return func(args[1], args[2], args[3], args[4], args[5], args[6])
        end
    end

---------------------------------------------------------------------------
--
-- Naming utils 
--
---------------------------------------------------------------------------

    function fbuild.targetName2(obj, cfg, join)
        local name = obj.name or obj
        return table.concat({ name, cfg.platform, cfg.buildcfg }, iif(join, join, "-"))
    end

--- 
-- Returns the target platform name for the given config
---
    function fbuild.targetPlatform(cfg)
        local config = cfg.config or cfg
        return table.concat({ config.system, config.architecture, (config.toolset:gsub("%-", "_")) }, "|")
    end

---
-- Returns the fbuild name for the platform structure to be used for ObjectList and Library functions 
--- 
    function fbuild.targetPlatformStruct(cfg)
        return fbuild.targetPlatformCompilerStruct(cfg)
    end

---
-- Returns the struct name for the given platforms additional defined compiler, additional compiler suffixes: res
---
    function fbuild.targetPlatformCompilerStruct(cfg, suffix)
        local config = cfg.config or cfg
        return ((table.concat({ "platform", cfg.system, cfg.architecture, config.toolset, suffix }, "_")):gsub("%-", "_"))
    end


---------------------------------------------------------------------------
--
-- Generation utils 
--
---------------------------------------------------------------------------

---
-- Emits an include statement with the given path to the output file
---
    function fbuild.include(path) 
        p.x('#include "%s"', path)
    end

---
-- Emits an Alias function call
--- 
    function fbuild.emitAlias(name, targets, fmap)
        fmap = iif(fmap, fmap, function(e) return e end)

        fbuild.emitFunction("Alias", name, { 
            call(fbuild.emitList, "Targets", {
                call(fbuild.emitListItems, targets, fmap)
            })
        })
    end

---------------------------------------------------------------------------
--
-- Emitting functions, statements, structs and scopes
--
---------------------------------------------------------------------------


---
-- Emits a Using statement to the output file 
---
    function fbuild.emitUsing(value, ...)
        p.x("Using( .%s )", value:format(...))
    end

---
-- Emits a function call to the output file 
---
    function fbuild.emitFunction(name, alias, inner, after, ...)
        if alias and #alias > 0 then
            p.x("%s( '%s' )", name, alias)
        else
            p.x("%s()", name)
        end
        fbuild.emitScope(inner, after, ...)
    end

---
-- Emits a for loop statement to the output file 
---
    function fbuild.emitForLoop(arg, array, inner, after, ...)
        p.x("ForEach( .%s in .%s ) ", arg, array)
        fbuild.emitScope(inner, after, arg, ...)
    end

---
-- Emits a list definition to the output file 
---
    function fbuild.emitList(name, inner, after, ...)
        p.x(".%s = ", name)
        fbuild.emitScope(inner, after, ...)
    end

---
-- Emits items to the output file 
---
    function fbuild.emitListItems(items, fmap, check)
        if not fmap then 
            fmap = function(e) return e end
        end

        for _, item in pairs(items) do 
            if not check or check(item) then
                p.x("'%s', ", fmap(item))
            end
        end
    end

---
-- Emits a scope construct to the output file 
---
    function fbuild.emitScope(inner, after, ...)
        p.push("{")
        p.callArray(inner, ...)
        p.pop("}")
        p.callArray(after, ...)
        p.x("")
    end

---
-- Emits a struct definition to the output file 
---
    function fbuild.emitStruct(name, inner, after, ...)
        p.x(".%s = ", name)
        p.push("[")
        p.callArray(inner, ...)
        p.pop("]")
        p.callArray(after, ...)
        p.x("")
    end
