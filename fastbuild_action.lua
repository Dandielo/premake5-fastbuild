--
-- actions/fastbuild/fastbuild.lua
-- Extend the existing exporters with support for FASTBuild
-- Copyright (c) 2017-2017 Daniel Penkała 
--

    local p = premake
    local fastbuild = p.fastbuild

---
-- Define a helper command that will hold available platforms 
--- 
p.api.register {
    name = "fbcompiler",
    scope = "workspace",
    kind = "string"
}

p.api.register { 
    name = "fbunitymaxfiles",
    scope = "project",
    kind = "number"
}

newoption { 
    trigger     = "fb-vstudio",
    description = "Adds tools projects to the solution"
}

newoption {
    trigger = "fb-cache-path",
    description = "Sets the cache path in the Settings section which will override the ENV variable (if set)"
}

newoption {
    trigger = "fb-unity-builds",
    description = "Creates unity function calls and supplies the unity blobs to object lists instead of all files."
}

p.api.addAllowed("flags", "FBUnityBuild")
p.api.addAllowed("flags", "FBUnityBuildDisabled")

---
-- Define the FASTBuild export action.
---

    newaction {
        -- Metadata for the command line and help system

        trigger     = "fastbuild",
        shortname   = "FASTBuild ",
        description = "Generate FASTBuild project files",

        -- The capabilities of this action
        valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib", "Makefile", "None", "Utility" },
        valid_languages = { "C", "C++" },
        valid_tools     = { },

        -- Workspace and project generation logic
        onWorkspace = function(wks)
            if _OPTIONS['fb-vstudio'] then 
                wks.vstudio_enabled = true
            end

            wks.fbuild = { }
            fastbuild.generateSolution(wks)
        end,

        onProject = function(prj)
            if _OPTIONS['fb-vstudio'] then 
                prj.vstudio_enabled = true
            end

            prj.fbuild = { }
            fastbuild.generateProject(prj)
        end,

        onRule = function(rule)
            fastbuild.generateRule(rule)
        end,

        onCleanWorkspace = function(wks)
        end,

        onCleanProject = function(prj)
        end,

        onCleanCompiler = function(cl)
        end,

        onCleanTarget = function(prj)
        end,

    }
    
