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
            m.globals,
            m.settings,
            m.compilers,
            -- Projects
            m.allStructs,
            m.includeProjects,
            m.allTargets,
            iif(_OPTIONS["fb-vstudio"], m.emitSolutionFunc, fbuild.fmap.pass)
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
            local toolset = compiler.toolset
            local path = compiler.path

            assert(name, "The given compiler does not have a name?")
            assert(system, "Compiler %s does not have any target system defined!", name)
            assert(architecture, "Compiler %s does not have any architecture defined!", name)
            assert(toolset, "Compiler %s does not any toolset defined!", name)
            assert(path, "Where can I find the given compiler? %s [%s]", name, platform)

            -- Include the compiler file and save it in the list
            fbuild.include(fbuild.path(wks, path))

            -- Save the system | architecture pair
            local target_platform = system .. "|" .. architecture .. "|" .. toolset
            assert(not available_compilers[target_platform], "Compiler for target platform %s already exists", target_platform)
            available_compilers[target_platform] = true
        end)

        -- Check if we have a compiler for each workspace configuration (these are required to be present)
        for config in workspace.eachconfig(wks) do
            local target_platform = fbuild.targetCompilerPlatform(config)
            local is_compiler_present = available_compilers[target_platform]
            assert(is_compiler_present, ("No compiler found for target platform %s!"):format(target_platform))
        end

        -- Save the compiler list for later use
        wks.compilers = available_compilers
    end


---
-- Write global values info the solution file
---

    m.elements.globals = function(wks)
        return {
            fbuild.call(fbuild.emitStructValue, "WorkspaceLocation", wks.location, false, fbuild.fmap.quote)
        }
    end

    function m.globals(wks)
        p.x("\n// FASTBuild global values ")
        p.x("//-----")
        p.callArray(m.elements.globals, wks)
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









    -- function m.solutionProjectFolders(wks)
    --     -- p.x(".%s_SolutionFolders = { }", wks.name)
    --     -- wks.fbuild.projects:for_each_group(function(group, prjs)
    --     --     p.push(".%sFolder_%s = [", wks.name, group)
    --     --     p.x(".Path = '%s'", group)
    --     --     p.push(".Projects = {")
    --     --     for _, prj in pairs(prjs) do
    --     --         p.x("'%s_vcxproj', ", prj)
    --     --     end
    --     --     p.pop("}")
    --     --     p.pop("]")
    --     --     p.x(".%s_SolutionFolders + .%sFolder_%s", wks.name, wks.name, group)
    --     -- end)
    -- end
