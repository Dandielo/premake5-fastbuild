--
-- actions/fastbuild/fastbuild.lua
-- Extend the existing exporters with support for FASTBuild
-- Copyright (c) 2017-2017 Daniel Penkała 
--

    local p = premake
    p.fastbuild.fbsln = { }

    local tree = p.tree
    local project = p.project
    local workspace = p.workspace

    local fbuild = p.fastbuild
    local dependency_resolver = fbuild.dependency_resolver



    local fastbuild = p.fastbuild
    local fbuild = fastbuild
    local fbsln = fastbuild.fbsln
    local f = fastbuild.utils

    local m = p.fastbuild.fbsln

---
-- Add namespace for element definition lists for p.callArray()
---

    m.elements = {}


--
-- Return the list of sections contained in the solution.
-- TODO: Get rid of this when the MonoDevelop module no longer needs it
--
    
    m.elements.workspace = function(wks) 
        return { 
            -- General 
            m.header,
            m.settings,
            m.compilers,
            -- Projects 
            m.allStructs,
            m.includeProjects,
            m.allTargets,
            m.solutionVisualStudio
        }
    end
    
---
-- Define the FASTBuild solution generation function
---

    function m.generate(wks)
        p.callArray(m.elements.workspace, wks)
    end

---
-- Prints the workspace file header
---
    function m.header(wks) 
        f.section("FASTBuild Solution: %s", wks.name)
    end

---
-- Tries to find the defined compiler file definitions and includes them to the workspace 
---
    function m.compilers(wks)
        p.x("\n// Available compilers ")
        p.x("//-----")

        -- A list of all available compilers
        local available_compilers = { }

        -- Iterate over each compiler and save the architecture | system pair
        table.foreachi(wks.fbcompilers, function(compiler)
            local name = compiler.name 
            local system = compiler.system
            local architecture = compiler.architecture
            local path = compiler.path

            assert(name, "The given compiler does not have a name?")
            assert(system, "Compiler %s does not have any target system defined!", name)
            assert(architecture, "Compiler %s does not have any architecture defined!", name)
            assert(path, "Where can I find the given compiler? %s [%s]", name, platform)

            -- Include the compiler file and save it in the list
            fbuild.include(fbuild.path(wks, path))

            -- Save the system | architecture pair
            local target_platform = system .. "|" .. architecture
            assert(not available_compilers[target_platform], "Compiler for target platform %s already exists", target_platform)
            available_compilers[target_platform] = true
        end)

        -- Check if we have a compiler for each workspace configuration (these are required to be present)
        for config in workspace.eachconfig(wks) do
            local target_platform = fbuild.targetPlatform(config)
            local is_compiler_present = available_compilers[target_platform]
            assert(is_compiler_present, ("No compiler found for target platform %s!":format(target_platform))
        end

        -- Save the compiler list for later use 
        wks.compilers = available_compilers
    end

---
-- Write settings info the solution file 
---
    m.elements.settings = function(wks)
        return {
            m.settingCachePath
        }
    end

    function m.settings(wks)
        p.x("\n// FASTBuild settings ")
        p.x("//-----")

        p.x("Settings") -- The 'Settings' element in fastbuild is quite special, it's not a function call nor a struct so we 'emulate' it with a scope 
        fbuild.emitScope(m.elements.settings)
    end

    function m.settingCachePath(wks)
        local cache_path = _OPTIONS["fb-cache-path"]
        if cache_path and #cache_path > 0 then 
            p.x(".CachePath = '%s'", path.translate(cache_path))
        end
    end

---
-- Emit 'All' structs which will hold all targets to be compiled when using an 'All' target
---
    function m.allStructs(wks)
        p.x("\n// All structures (used to create 'All' alliases)")
        p.x("//-----")

        for cfg in p.workspace.eachconfig(wks) do
            p.x(".AllTargets_%s = { }", fbuild.solutionConfig(cfg))
        end
    end

---
-- Write out the list of projects and groups contained by the solution.
---
    function m.includeProjects(wks)
        p.x("\n// Included projects ")
        p.x("//-----")

        -- Resolves project dependencies and calls the callback for each project in a ordered way
        dependency_resolver.eachproject(wks, function(prj)
            local location = fbuild.path(wks, p.filename(prj, ".prj.bff"))
            fbuild.include(location)
        end)
    end



    function m.allTargets(wks)
        p.x("\n// All targets (for default configurations) ")
        p.x("//-----")

        for cfg in workspace.eachconfig(wks) do 
            fbuild.emitFunction("Alias", fbuild.targetName2("all", cfg), {
                fbuild.call(p.x, ".Targets = .AllTargets_%s", fbuild.solutionConfig(cfg))
            })
        end
    end

---------------------------------------------------------------------------
--
-- Visual studio project support 
--
---------------------------------------------------------------------------


    m.elements.vstudio = function(wks)
        if not wks.vstudio_enabled then 
            return { } 
        end

        return { 
            m.solutionVStudioConfigs,
            m.solutionProjectFolders,
            m.solutionAllProject,
            m.solutionVStudioBegin,
            m.solutionVStudioProjects,
            m.solutionVStudioEnd,
        } 
    end

    function m.solutionProjectFolders(wks)
        p.x(".%s_SolutionFolders = { }", wks.name)
        -- wks.fbuild.projects:for_each_group(function(group, prjs)
        --     p.push(".%sFolder_%s = [", wks.name, group)
        --     p.x(".Path = '%s'", group)
        --     p.push(".Projects = {")
        --     for _, prj in pairs(prjs) do 
        --         p.x("'%s_vcxproj', ", prj)
        --     end
        --     p.pop("}")
        --     p.pop("]")
        --     p.x(".%s_SolutionFolders + .%sFolder_%s", wks.name, wks.name, group)
        -- end)
    end

    function m.solutionVisualStudio(wks)
        p.x("")
        f.section("Visual Studio solution")
        p.callArray(m.elements.vstudio, wks)
    end

    function m.solutionVStudioConfigs(wks)
        p.x(".%sSolutionConfigs = { }", wks.name)

        for cfg in workspace.eachconfig(wks) do
            p.x("\n// VisualStudio Config: %s|%s", cfg.platform, cfg.buildcfg)
            p.push(".%s_%s_SolutionConfig = [", wks.name, fastbuild.solutionConfig(cfg))
            p.x(".Platform = '%s'", cfg.platform)
            p.x(".Config = '%s'", cfg.buildcfg)
            p.pop("]")
            p.x(".%sSolutionConfigs + .%s_%s_SolutionConfig\n", wks.name, wks.name, fastbuild.solutionConfig(cfg))
        end
    end

    function m.solutionAllProject(wks)
        p.x("VCXProject( 'all_vcxproj' )")
        p.push("{")
        p.x(".ProjectOutput = '..\\build\\fastbuild\\All.vcxproj'", fastbuild.path(wks, wks.location))
        p.x(".ProjectConfigs = .%sSolutionConfigs", wks.name)
        p.x(".ProjectBuildCommand = 'cd \"^$(SolutionDir)\" &amp; fbuild -config %s.wks.bff -ide -monitor -dist -cache all-^$(Platform)-^$(Configuration)'", wks.filename)
        p.x(".ProjectRebuildCommand = 'cd \"^$(SolutionDir)\" &amp; fbuild -config %s.wks.bff -ide -monitor -dist -cache -clean all-^$(Platform)-^$(Configuration)'", wks.filename)
        p.x(".ProjectCleanCommand = 'cd \"^$(SolutionDir)\" &amp; fbuild -config %s.wks.bff -ide -monitor -dist -cache -clean'", wks.filename)
        p.pop("}")
    end

    function m.solutionVStudioBegin(wks)
        p.x("VSSolution( '%s_sln' )", wks.name)
        p.push("{")
        p.x(".SolutionOutput = '%s\\%s_fb.sln'", fastbuild.path(wks, wks.location), wks.name)
        p.x(".SolutionConfigs = .%sSolutionConfigs", wks.name)
        p.x(".SolutionBuildProject = 'all_vcxproj'")
        -- p.x(".SolutionFolders = .%s_SolutionFolders", wks.name)

        p.push(".execDeps = [")
        p.push(".Projects = {")
        for prj in workspace.eachproject(wks) do 
            if prj.kind == p.CONSOLEAPP then 
                p.x("'%s_vcxproj',", prj.name)
            end
        end
        p.pop("}")
        p.x(".Dependencies = { 'all_vcxproj' }")
        p.pop("]")

        p.x(".SolutionDependencies = { .execDeps }")
    end

    function m.solutionVStudioProjects(wks)
        p.push(".SolutionProjects = {")
        -- wks.fbuild.projects:for_each(function(prj)
        --     p.x("'%s_vcxproj',", prj.name)
        -- end)
        p.x("'all_vcxproj',")
        p.pop("}")
        -- body
    end

    function m.solutionVStudioEnd(wks)
        p.pop("}")
    end
