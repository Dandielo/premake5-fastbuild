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
            m.header,
            m.compilers,
            m.settings,
            m.configurations,
            m.buildConfigurations,
            m.projects,
            m.targets,
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
            assert(is_compiler_present, "No compiler for for target platform %s!", target_platform)
        end

        -- Save the compiler list for later use 
        wks.compilers = available_compilers
    end

---
-- Write settings info the solution file 
---
    function m.settings(wks)
        p.x("")
        f.section("Settings")
        p.push("Settings {")
        local cache_path = _OPTIONS["fb-cache-path"]
        if cache_path and #cache_path > 0 then 
            p.x(".CachePath = '%s'", path.translate(cache_path))
        end
        p.pop("}")
    end

--
-- Write out the list of projects and groups contained by the solution.
--

    function m.projects(wks)
        local tr = p.workspace.grouptree(wks)

        assert(not wks.targets)
        wks.targets = { }

        p.w()
        f.section("Projects") 

        local projects = { 
            list = { },
            paths = { },
            groups = { [""] = { } },
            groups_stack = { "" },
            group_current = ""
        }

        function projects.onleaf(self)
            return function(n)
                local prj = n.project

                -- Build a relative path from the solution file to the project file
                local prjpath = p.filename(prj, ".prj.bff")
                prjpath = fastbuild.path(prj.workspace, prjpath)

                -- Sort by dependencies 
                self:add(prj, prjpath)

                -- p.x('#include "%s"', prjpath)
                -- sln2005.projectdependencies(prj)
            end
        end

        function projects.onbranch(self)
            return function(n)
                self.current_group = n.name
                self.groups[n.name] = self.groups[n.name] or { }
                table.insert(self.groups_stack, n.name)
            end
        end

        function projects.onbranchexit(self)
            return function()
                table.remove(self.groups_stack, #self.groups_stack)
                self.current_group = self.groups_stack[#self.groups_stack]
            end
        end

        function projects.add(self, prj, path)
            local refs = project.getdependencies(prj, 'all')
            for _, ref in pairs(refs or { }) do
                self:add(ref)
            end

            if path and not self.paths[prj.name] then 
                self.paths[prj.name] = path
                table.insert(self.groups[self.current_group], prj.name)
            end

            table.insert(self.list, prj)
        end

        function projects.remove_duplicates(self)
            local found = { }
            local sorted = { }
            for _, prj in pairs(self.list) do 
                if not found[prj.name] then
                    found[prj.name] = prj
                    table.insert(sorted, prj)
                end
            end
            self.list = sorted
        end

        function projects.for_each(self, func)
            for _, prj in pairs(self.list) do 
                func(prj, self.paths[prj.name])
            end
        end

        function projects.for_each_group(self, func)
            for key, prjs in pairs(self.groups) do 
                func(key, prjs)
            end
        end

        tree.traverse(tr, {
            onleaf = projects:onleaf(),
            onbranch = projects:onbranch(),
            onbranchexit = projects:onbranchexit()
        })

        for cfg in p.workspace.eachconfig(wks) do
            p.x(".AllTargets_%s = { }", fastbuild.solutionConfig(cfg))
        end
        p.x("")

        projects:remove_duplicates()
        projects:for_each(function(prj, path) 
            p.x('#include "%s"', path)
        end)

        wks.fbuild.projects = projects
    end

-- Write out the list of configurations in the solution.
--

    function m.configurations(wks)
        p.w()
        f.section("Configurations") 
    end

--
-- Write out the tables that map solution configurations to project configurations.
--

    function m.buildConfigurations(wks)
        p.w()
        f.section("Build configurations") 

        local descriptors = {}

        -- Create 
        for cfg in p.workspace.eachconfig(wks) do
            local platform = fastbuild.solutionPlatform(cfg)
            table.insert(descriptors, string.format(".%s_%s", cfg.buildcfg, platform))
        end
    end

    function m.targets(wks)
        p.w()
        f.section("Target Aliases")

        for cfg in p.workspace.eachconfig(wks) do
            p.x("Alias('all-%s-%s')", cfg.platform, cfg.buildcfg)
            p.push("{")
            p.x(".Targets = .AllTargets_%s", fastbuild.solutionConfig(cfg))
            p.pop("}")
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
        wks.fbuild.projects:for_each_group(function(group, prjs)
            p.push(".%sFolder_%s = [", wks.name, group)
            p.x(".Path = '%s'", group)
            p.push(".Projects = {")
            for _, prj in pairs(prjs) do 
                p.x("'%s_vcxproj', ", prj)
            end
            p.pop("}")
            p.pop("]")
            p.x(".%s_SolutionFolders + .%sFolder_%s", wks.name, wks.name, group)
        end)
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
        p.x(".SolutionFolders = .%s_SolutionFolders", wks.name)

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

        p.push(".SolutionDependencies = { .execDeps }")
    end

    function m.solutionVStudioProjects(wks)
        p.push(".SolutionProjects = {")
        wks.fbuild.projects:for_each(function(prj)
            p.x("'%s_vcxproj',", prj.name)
        end)
        p.x("'all_vcxproj',")
        p.pop("}")
        -- body
    end

    function m.solutionVStudioEnd(wks)
        p.pop("}")
    end
