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
            m.settings,
            m.toolsets,
            m.platforms,
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

    function m.header(wks) 
        f.section("FASTBuild Solution: %s", wks.name)
    end


---
-- Write settings info the solution file 
---
    function m.settings(wks)
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

--
-- Write out the list of toolsets in the solution.
--

    function m.toolsets(wks)
        p.w()
        f.section("Toolsets")
        
        assert(not wks.toolsets)
        wks.toolsets = { }

        local toolsets = fastbuild.toolsets.findToolsets(wks)
        local function writeToolset(name, toolset)
            f.struct_begin("toolset_%s", name)
            f.struct_pair("VSBasePath", toolset.VSBasePath)
            f.struct_pair("WindowsSDKBasePath", toolset.WindowsSDKBasePath)
            p.w()
            f.struct_pair("x64VSBinBasePath", toolset.x64VSBinBasePath)
            f.struct_pair("x64VSIncludeDirs", toolset.x64VSIncludeDirs)
            f.struct_pair("x64VSLibDirs", toolset.x64VSLibDirs)
            p.w()
            f.struct_pair("x86VSBinBasePath", toolset.x86VSBinBasePath)
            f.struct_pair("x86VSIncludeDirs", toolset.x86VSIncludeDirs)
            f.struct_pair("x86VSLibDirs", toolset.x86VSLibDirs)
            p.w()
            f.struct_pair("VSAssembly", toolset.Assembly)
            f.struct_pair("VSCompiler", toolset.Compiler)
            f.struct_pair("VSLinker", toolset.Linker)
            f.struct_pair("VSLibrarian", toolset.Librarian)
            f.struct_end()
        end

        local function writeCompiler(name, toolset)
            p.push("{")
            p.x("Using( .toolset_msc141 )")
            p.x("Compiler( 'compiler_%s' )", name)
            p.push("{")
            p.x(".Executable = '$x64VSBinBasePath$\\$VSCompiler$'")
            f.struct_pair("ExtraFiles", toolset.x64CompilerExtraFiles)
            p.pop("}")
            p.pop("}")
        end

        for name, toolset in pairs(toolsets) do
            writeToolset(name, toolset)
            writeCompiler(name, toolset)

            table.insert(wks.toolsets, { 
                name = name, 
                data = toolset,
            })
        end
    end

--
-- Write out the list of platforms in the solution.
--

    function m.platforms(wks)
        p.w()
        f.section("Platforms")

        wks.toolchains = { }

        local platform_toolset_pairs = { }
        table.foreachi(wks.platforms, function(platform)
            table.foreachi(wks.toolsets, function(toolset)
                table.insert(platform_toolset_pairs, { platform = platform, toolset = toolset.name })
            end)
        end)

        table.foreachi(platform_toolset_pairs, function(pair)
            f.struct_begin("toolchain_%s_%s", pair.toolset, pair.platform)
            p.w("Using( .toolset_%s )", pair.toolset)

            p.w()
            f.struct_pair("Compiler", "compiler_%s", pair.toolset) -- "$%sVSBinBasePath$\\$VSCompiler$", pair.platform)
            f.struct_pair("CompilerOptions", '"%1"')
            f.struct_pair_append(' /Fo"%2"')
            f.struct_pair_append(' /c')
            f.struct_pair_append(' /nologo')
            f.struct_pair_append(' /FS')
            p.w()
            f.struct_pair("PCHOptions", '"%1"')
            f.struct_pair_append(' /Fo"%3"')
            f.struct_pair_append(' /c')
            f.struct_pair_append(' /nologo')
            f.struct_pair_append(' /FS')
            p.w()
            f.struct_pair("Linker", "$%sVSBinBasePath$\\$VSLinker$", pair.platform)
            f.struct_pair("LinkerOptions", ' /OUT:"%2"')
            f.struct_pair_append(' "%1"')
            f.struct_pair_append(' /NOLOGO')
            f.struct_pair_append(' /MACHINE:%s', pair.platform)
            f.struct_pair_append(' /NXCOMPAT')
            f.struct_pair_append(' /DYNAMICBASE')

            for _, lib in pairs({ "kernel32.lib", "user32.lib", "gdi32.lib", "winspool.lib", "comdlg32.lib", "advapi32.lib", "shell32.lib", "ole32.lib", "oleaut32.lib", "uuid.lib", "odbc32.lib", "odbccp32.lib", "delayimp.lib" }) do
                f.struct_pair_append(' "%s"', lib)
            end
            
            p.w()
            f.struct_pair("Librarian", "$%sVSBinBasePath$\\$VSLibrarian$", pair.platform)
            f.struct_pair("LibrarianOptions", ' /OUT:"%2"')
            f.struct_pair_append(' "%1"')
            f.struct_pair_append(' /NOLOGO')
            f.struct_pair_append(' /MACHINE:%s', pair.platform)
            
            p.w()
            p.w("ForEach( .IncDir in .%sVSIncludeDirs )", pair.platform)
            p.push("{")
            p.w("^PCHOptions + ' /I\"$IncDir$\"'")
            p.w("^CompilerOptions + ' /I\"$IncDir$\"'")
            p.pop("}")
            p.w()
            p.w(".LinkerOptions + ' /LIBPATH:\"$WindowsSDKBasePath$\\Lib\\x64\"'")
            p.w("ForEach( .LibDir in .%sVSLibDirs )", pair.platform)
            p.push("{")
            p.w("^LinkerOptions + ' /LIBPATH:\"$LibDir$\"'")
            p.pop("}")


            f.struct_end()

            wks.toolchains[pair.platform] = ("%s_%s"):format(pair.toolset, pair.platform)
        end)
    end

--
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
