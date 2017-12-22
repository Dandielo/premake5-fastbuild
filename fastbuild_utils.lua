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
            -- #todo use unpack or table.unpack, we dont want to only support premake with lua 5.3+
            return func(args[1], args[2], args[3], args[4], args[5], args[6])
        end
    end

    function fbuild.checkCompilers(prj)
        local wks = prj.workspace
        local configs_have_compilers = true

        for cfg in p.project.eachconfig(prj) do
            configs_have_compilers = configs_have_compilers and wks.compilers[fbuild.targetCompilerPlatform(cfg)] ~= nil
        end

        return configs_have_compilers
    end


    function fbuild.vstudioProjectToolset(prj)
        return (prj.toolset or ""):match("msc%-(v%d+)") or prj.toolset
    end


---------------------------------------------------------------------------
--
-- Naming utils
--
---------------------------------------------------------------------------

---
-- Filters nil values from the given (array or table) and returs an ARRAY!
---
    local function filterempty(tab)
        local result = { }
        for _, v in pairs(tab) do
            if v then
                table.insert(result, v)
            end
        end
        return result
    end



---
-- Returns a generated name for project configuration scopes
---

    local function generatedNameConfig(separator, cfg, prefix, suffix)
        cfg = cfg.config or cfg
        local prj = cfg.project
        return table.concat(filterempty{ prefix, prj.name, cfg.platform, cfg.buildcfg, suffix }, separator)
    end



---
-- Returns a generated name for project and workspace scopes
---

    local function generatedNameProject(separator, prj, prefix, suffix)
        prj = prj.project or prj
        return table.concat(filterempty{ prefix, iif(prj.name, prj.name, prj), suffix }, separator)
    end



---
-- Returns a string separated with 'minus' characters
---

    function fbuild.targetName2(obj, cfg, join)
        local name = obj.name or obj
        return table.concat({ name, cfg.platform, cfg.buildcfg }, iif(join, join, "-"))
    end


    function fbuild._targetName(cfg, prefix, suffix)
        return iif(cfg.project and cfg.project ~= cfg, generatedNameConfig, generatedNameProject)("-", cfg, prefix, suffix)
    end



---
-- Returns a string separated with 'underscore' characters
---

    function fbuild.listName(cfg, prefix, suffix)
        return iif(cfg.project, generatedNameConfig, generatedNameProject)("_", cfg, prefix, suffix)
    end



---
-- Returns a string separated with 'underscore' characters
---

    function fbuild.structName(cfg, prefix, suffix)
        return iif(cfg.project, generatedNameConfig, generatedNameProject)("_", cfg, prefix, suffix)
    end



---
-- Returns the target platform name for the given config
---

    function fbuild.targetPlatform(cfg)
        local config = cfg.config or cfg
        return table.concat(filterempty{ config.system, config.architecture }, "|")
    end



---
-- Returns the fbuild name for the platform structure to be used for ObjectList and Library functions
---

    function fbuild.targetCompilerPlatform(cfg)
        local config = cfg.config or cfg
        return table.concat(filterempty{ config.system, config.architecture, (config.toolset:gsub("%-", "_")) }, "|")
    end



---
-- Returns the struct name for the given platforms additional defined compiler, additional compiler suffixes: res
---

    function fbuild.targetCompilerPlatformStruct(cfg, suffix)
        local config = cfg.config or cfg
        return ((table.concat(filterempty{ "platform", config.system, config.architecture, config.toolset, suffix }, "_")):gsub("%-", "_"))
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
            fbuild.call(fbuild.emitList, "Targets", {
                fbuild.call(fbuild.emitListItems, targets, fmap)
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

    function fbuild.emitListItems(items, fmap, ...)
        fmap = iif(fmap, fmap, fbuild.fmap.pass)

        for _, item in ipairs(items) do
            local val = fmap(item, ...)
            if val then
                p.x("%s, ", val)
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



---
-- Emits a struct value definition
---

    function fbuild.emitStructValue(name, value, append, fmap)
        p.x(".%s %s %s", name, iif(append, "+", "="), iif(fmap, fmap, fbuild.fmap.pass)(value))
    end



---
-- Emits to parent struct value definition
---

    function fbuild.emitParentStructValue(name, value, fmap)
        p.x("^%s %s %s", name, "+", iif(fmap, fmap, fbuild.fmap.pass)(value))
    end



---
-- FMap functions so we can later use them without defining them everywhere
---

    fbuild.fmap = { }
    local fmap = fbuild.fmap

    function fmap.pass(value)
        return value
    end

    function fmap.quote(value)
        return ("'%s'"):format(tostring(value))
    end

    function fmap.variable(value)
        return (".%s"):format(tostring(value))
    end

    function fmap.list(values)
        return ("{ %s }"):format(table.concat(values, ", "))
    end
