--! fastbuild_solution.lua
--! Extends premake5 with a FASTBuild exporter.
--! Copyright (c) 2017-2017 Daniel Penkała

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



--! A namespace for call array elements.
--! @note An element entity of similar properties, grouped when generating the output file.

    m.elements = {}


--! Holds the workspace call array.

    m.elements.workspace = function(wks)
        return {
            -- General
            m.header,
            m.compilers,
            m.globals,
            m.settings,
            -- Projects
            m.allStructs,
            m.includeProjects,
            m.allTargets,
            iif(_OPTIONS["fb-vstudio"], m.emitSolutionFunc, fbuild.fmap.pass)
        }
    end


--! Generates a fastbuild 'workspace' file.

    function m.generate(wks)
        p.callArray(m.elements.workspace, wks)
    end


--! Generates the workspace file header.

    function m.header(wks)
        f.section("FASTBuild Solution: %s", wks.name)
    end



--! Iterates over all defined compilers and creates a best match table for all target combinations. 
--! @note More on this later.

    function m.compilers(wks)
        p.x("\n// Available compilers ")
        p.x("//-----")

        -- A list of all available compilers
        local defined_compilers = { }
        local available_compilers = { }

        -- Creates a table that can passed to the 'fbuild.config_name' function, from the given arguments
        local function config_table(system, arch, toolset)
            return { system = system, architecture = arch, toolset = toolset }
        end

        -- Creates a list of all confiuration permutations? for the specific compiler.
        local function config_name_permutations(system, arch, toolset)
            assert(system ~= nil)
            local result = { system } 

            if arch ~= nil then 
                table.insert(result, fbuild.config_name(config_table(system, arch)))
            end

            if toolset ~= nil then 
                table.insert(result, fbuild.config_name(config_table(system, nil, toolset)))
            end

            return result 
        end

        -- Iterate over each compiler and save the architecture | system pair
        table.foreachi(wks.fbcompilers, function(compiler)

            local system = iif(compiler.system, compiler.system, os.target())

            -- Is somewhere a default architecture for each system defined? 
            local architecture = iif(compiler.architecture, compiler.architecture, "x86_64")

            -- Is somewhere a default toolset defined for each system?
            local toolset = iif(compiler.toolset, compiler.toolset, nil)

            -- Generates an 'include' statement
            fbuild.include(fbuild.path(wks, compiler.path))

            -- Returns the compiler defined configuration name
            local config_name = fbuild.config_name(config_table(system, architecture, toolset)) 
            compiler_struct = "platform_" .. config_name:gsub("-", "_")

            defined_compilers[config_name] = compiler_struct
            available_compilers[config_name] = compiler_struct

            -- Use this compiler for matching but less specific configurations.
            local config_name_perms = config_name_permutations(system, architecture, toolset)
            table.foreachi(config_name_perms, function(config_name) 

                if not available_compilers[config_name] then 
                    available_compilers[config_name] = compiler_struct
                end

            end)

        end)

        -- Check if we have a compiler for each workspace configuration (these are required to be present)
        for config in workspace.eachconfig(wks) do
            local target_platform = fbuild.config_name(config)
            local is_compiler_present = available_compilers[target_platform]
            assert(is_compiler_present, ("No compiler found for target configuration %s!"):format(target_platform))
        end

        -- Save the compiler list for later use
        wks.compilers = available_compilers
    end


--! Holds the 'globals' call array.

    m.elements.globals = function(wks)
        return {
            fbuild.call(fbuild.emitStructValue, "WorkspaceLocation", wks.location, false, fbuild.fmap.quote)
        }
    end


--! Generates a section of values which should be available globally for all other generated files. 

    function m.globals(wks)
        p.x("\n// FASTBuild global values ")
        p.x("//-----")
        p.callArray(m.elements.globals, wks)
    end


--! Holds the 'settings' call array.

    m.elements.settings = function(wks)
        return {
            m.settingCachePath
        }
    end


--! Generates the 'settings' block.

    function m.settings(wks)
        p.x("\n// FASTBuild settings ")
        p.x("//-----")

        p.x("Settings") -- The 'Settings' element in fastbuild is quite special, it's not a function call nor a struct so we 'emulate' it with a scope
        fbuild.emitScope(m.elements.settings)
    end

--! Generates the cache path setting if set.

    function m.settingCachePath(wks)
        local cache_path = _OPTIONS["fb-cache-path"]
        if cache_path and #cache_path > 0 then
            p.x(".CachePath = '%s'", path.translate(cache_path))
        end
    end


--! Generates all? possible combinations for the 'all' alliases

    function m.allStructs(wks)
        p.x("\n// All structures (used to create 'All' alliases)")
        p.x("//-----")

        for cfg in p.workspace.eachconfig(wks) do
            p.x("%s = { }", fbuild.struct_name(cfg, "all"))
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
        p.x("// todo 'Alias' calls")

        -- for cfg in workspace.eachconfig(wks) do
        --     fbuild.emitFunction("Alias", fbuild.targetName2("all", cfg), {
        --         fbuild.call(p.x, ".Targets = .AllTargets_%s", fbuild.struct_name(cfg))
        --     })
        -- end
    end



---------------------------------------------------------------------------
--
-- VSSolution function call
--
---------------------------------------------------------------------------

    m.elements.vstudio_filters = function(wks)
        return {
        }
    end

    m.elements.vstudio = function(wks)
        return {
            m.solutionOutputLocation,
            m.solutionBuildProject,
            m.solutionFolders,
            m.solutionProjects,
            m.solutionDependencies,
        }
    end

---
-- Emits an additional "All" project which is used to build executable project with the f5 key, however it will always perform a full solution build
---

    function m.emitAllProject(wks)
        local function emitValue(name, value, fmap, ...)
            return fbuild.call(fbuild.emitStructValue, name, value:format(...), false, fmap)
        end

        fbuild.emitFunction("VCXProject", fbuild._targetName("All", nil, "vcxproj"), {
            emitValue("ProjectOutput", "..\\build\\fastbuild\\All.vcxproj", fbuild.fmap.quote),
            emitValue("ProjectConfigs", ".SolutionConfigs"),
            emitValue("ProjectBuildCommand", "cd \"$(SolutionDir)\" &amp; fbuild -config %s.wks.bff -ide -monitor -dist -cache all-$(Platform)-$(Configuration)", fbuild.fmap.quote, wks.filename),
            emitValue("ProjectRebuildCommand", "cd \"$(SolutionDir)\" &amp; fbuild -config %s.wks.bff -ide -monitor -dist -cache -clean all-$(Platform)-$(Configuration)", fbuild.fmap.quote, wks.filename),
            emitValue("ProjectCleanCommand", "cd \"$(SolutionDir)\" &amp; fbuild -config %s.wks.bff -ide -monitor -dist -cache -clean", fbuild.fmap.quote, wks.filename),
            emitValue("PlatformToolset", fbuild.vstudioProjectToolset(wks), fbuild.fmap.quote)
        })
    end



---
-- Emits an additional "RebuildSln" project which is used to rebuild the FastBuild solution
---

    function m.emitRebuildProject(wks)
        local function emitValue(name, value, fmap, ...)
            return fbuild.call(fbuild.emitStructValue, name, value:format(...), false, fmap)
        end

        fbuild.emitFunction("VCXProject", fbuild._targetName("Rebuild", nil, "vcxproj"), {
            emitValue("ProjectOutput", "..\\build\\fastbuild\\Rebuild.vcxproj", fbuild.fmap.quote),
            emitValue("ProjectConfigs", ".SolutionConfigs"),
            emitValue("ProjectBuildCommand", "cd \"$(SolutionDir)\" &amp; fbuild -config %s.wks.bff %s-sln", fbuild.fmap.quote, wks.filename, wks.name),
            emitValue("PlatformToolset", fbuild.vstudioProjectToolset(wks), fbuild.fmap.quote)
        })
    end



---
-- Emits the VSSolution function call which allows to create a FASTBuild compatible solution
---

    function m.emitSolutionFunc(wks)
        p.x("\n// VSSolution definiton ")
        p.x("//-----")

        m.emitSolutionConfigs(wks)
        m.emitAllProject(wks)
        m.emitRebuildProject(wks)
        m.emitSolutionProjectFolders(wks)
        fbuild.emitFunction("VSSolution", fbuild._targetName(wks, nil, "sln"), m.elements.vstudio, nil, wks)
    end



---
-- Emits the solution output location
---

    function m.solutionOutputLocation(wks)
        local filename = wks.name .. "_fb.sln"

        -- Emit the struct value
        fbuild.emitStructValue("SolutionOutput", filename, false, fbuild.fmap.quote)
    end



---
-- Emits the solution active build projecty (f5 enabled project)
---

    function m.solutionBuildProject(wks)
        local buildprj = fbuild._targetName("All", nil, "vcxproj")

        -- Emit the active build project (f5 enabled project)
        fbuild.emitStructValue("SolutionBuildProject", buildprj, false, fbuild.fmap.quote)
    end



---
-- Emits all projects which the solution should open
---

    function m.solutionProjects(wks)
        local function emitAdditionalProjects()
            p.x("%s,", fbuild.fmap.quote(fbuild._targetName("All", nil, "vcxproj")))
            p.x("%s", fbuild.fmap.quote(fbuild._targetName("Rebuild", nil, "vcxproj")))
        end

        -- Emits all solution projects in dependent order
        fbuild.emitList("SolutionProjects", { fbuild.emitListItems, emitAdditionalProjects }, nil, dependency_resolver.allprojects(wks), function(prj)
            if fbuild.checkCompilers(prj) then
                local target_name = fbuild._targetName(prj.name, nil, "vcxproj")
                return fbuild.fmap.quote(target_name)
            end
        end)
    end



---
-- Emits the solution folders setting for the given solution
---
    function m.solutionFolders(wks)
        fbuild.emitStructValue("SolutionFolders", fbuild.structName(wks, nil, "SolutionFolders"), false, fbuild.fmap.variable)
    end



---
-- Emits dependency declartions across solution projects
---

    function m.solutionDependencies(wks)
        -- Helps to emit the list within the emited struct
        local function emitExecutableProjectList(wks)
            fbuild.emitList("Projects", { fbuild.emitListItems }, nil, dependency_resolver.allprojects(wks), function(prj)

                -- Check it it's an 'App' project
                if prj.kind == p.CONSOLEAPP or prj.kind == p.WINDOWEDAPP then
                    local target_name = fbuild._targetName(prj.name, nil, "vcxproj")
                    return fbuild.fmap.quote(target_name)
                end
            end)
        end

        -- Helps to emit the dependencies list of the given 'App' projects
        local function emitExecutableDependencies(wks)
            local all_target = fbuild._targetName("All", nil, "vcxproj")
            fbuild.emitStructValue("Dependencies", { fbuild.fmap.quote(all_target) }, false, fbuild.fmap.list)
        end

        p.x("// Solution project dependencies")

        -- First emit the structure which will define dependencies to the 'All' project (we care only about 'executable' kinds)
        fbuild.emitStruct("MainSolutionDependency", { emitExecutableProjectList, emitExecutableDependencies }, {
            fbuild.call(fbuild.emitStructValue, "SolutionDependencies", { ".MainSolutionDependency" }, false, fbuild.fmap.list)
        }, wks)
    end



---
-- Emits the solution configurations
---

    function m.emitSolutionConfigs(wks)
        p.x("// List of all configurations")
        fbuild.emitList("Configurations", { fbuild.emitListItems }, nil, wks.configurations, fbuild.fmap.quote)

        p.x("// List of all platforms")
        fbuild.emitList("Platforms", { fbuild.emitListItems }, nil, wks.platforms, fbuild.fmap.quote)

        p.x("// The actual solution configuration list")
        fbuild.emitStructValue("SolutionConfigs", "{ }")
        p.x("")

        local call = fbuild.call
        fbuild.emitForLoop("Platform", "Platforms",
        {
            call(fbuild.emitForLoop, "Config", "Configurations",
            {
                call(fbuild.emitStruct, "Configuration", {
                    call(fbuild.emitStructValue, "Platform", "$Platform$", false, fbuild.fmap.quote),
                    call(fbuild.emitStructValue, "Config", "$Config$", false, fbuild.fmap.quote)
                }),
                call(fbuild.emitParentStructValue, "SolutionConfigs", ".Configuration")
            })
        })
    end

    function m.emitSolutionProjectFolders(wks)
        for _, group in ipairs(dependency_resolver.allgroups(wks)) do

            if #group.projects > 0 then

                local struct_name = ("%s_SolutionFolder"):format(group.name:gsub("/", "_"))

                fbuild.emitStruct(struct_name, {
                    fbuild.call(fbuild.emitStructValue, "Path", group.name, false, fbuild.fmap.quote),
                    fbuild.call(fbuild.emitList, "Projects", { fbuild.emitListItems }, nil, group.projects, function(prj)

                        if fbuild.checkCompilers(prj) then

                            return fbuild.fmap.quote(fbuild._targetName(prj.name, nil, "vcxproj"))

                        end

                    end)
                })

            end

        end

        -- Emit solution folder for FBuild special generated projects
        fbuild.emitStruct(fbuild.structName(wks, nil, "FBuildSolutionFolder"), {
            fbuild.call(fbuild.emitStructValue, "Path", "_fbuild", false, fbuild.fmap.quote),
            fbuild.call(fbuild.emitList, "Projects", { fbuild.emitListItems }, nil, { "All", "Rebuild" }, function(name)

                return fbuild.fmap.quote(fbuild._targetName(name, nil, "vcxproj"))

            end)
        })

        -- Emit the SolutionFolders list
        local inner = {
            fbuild.emitListItems,
            fbuild.call(p.x, ".%s", fbuild.structName(wks, nil, "FBuildSolutionFolder"))
        }

        fbuild.emitList(fbuild.structName(wks, nil, "SolutionFolders"), inner, nil, dependency_resolver.allgroups(wks), function(group)

            if #group.projects > 0 then

                local struct_name = (".%s_SolutionFolder"):format(group.name:gsub("/", "_"))
                return struct_name

            end

        end)
    end
