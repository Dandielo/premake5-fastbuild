--
-- actions/fastbuild/fastbuild.lua
-- Extend the existing exporters with support for FASTBuild
-- Copyright (c) 2017-2017 Daniel Penkała
--

    local p = premake
    local project = p.project
    local fastbuild = p.fastbuild
    local f = fastbuild.utils

---
-- Define the FASTBuild build functions
---

    function fastbuild.generateSolution(wks)
        p.indent("    ")
        p.eol("\r\n")
        p.escaper(fastbuild.esc)

        p.generate(wks, ".wks.bff", fastbuild.fbsln.generate)
    end

    function fastbuild.generateProject(prj)
        p.indent("    ")
        p.eol("\r\n")
        p.escaper(fastbuild.esc)

        p.generate(prj, ".prj.bff", fastbuild.fbprj.generate)
    end

    function fastbuild.generateCompiler(cl)
        p.indent("    ")
        p.eol("\r\n")
        p.escaper(fastbuild.esc)

        p.generate(cl, ".compiler.bff", fastbuild.fbcl.generate)
    end

    function fastbuild.generateRule()
        print("FASTBuild Rule")
    end


---
-- Apply XML escaping on a value to be included in an
-- exported project file.
---

    function fastbuild.esc(value)
        local vs_mappings = {
            VSInstallDir = "$VSBasePath$\\",
            VsInstallRoot = "$VSBasePath$\\",
            SolutionDir = "$WorkspaceLocation$"
        }

        if type(value) ~= "string" then
            return value
        end

        value = value:gsub("%$%((.-)%)", function(match)
            return vs_mappings[match] or ("$(%s)"):format(match)
        end)
        value = value:gsub("%$(%(.-%))",  "^$%1")

        return value
    end

    fastbuild.architectures =
    {
        win32   = "x86",
        x86     = "x86",
        x86_64  = "x64",
    }


    local function architecture(system, arch)
        return fastbuild.architectures[arch] or fastbuild.architectures[system]
    end


---
-- Prepare a path value for output in a FASTBuild project or solution.
-- Converts path separators to backslashes, and makes relative to the project.
--
-- @param cfg
--    The project or configuration which contains the path.
-- @param value
--    The path to be prepared.
-- @return
--    The prepared path.
---

    function fastbuild.path(cfg, value)
        cfg = cfg.workspace or cfg
        local dirs = path.translate(project.getrelative(cfg, value))

        if type(dirs) == 'table' then
            dirs = table.filterempty(dirs)
        end

        return dirs
    end


    function fastbuild.projectLocation(prj)
        local prj = prj.project or prj
        local wks = prj.workspace

        local project_script_location = path.getdirectory(prj.script)
        local workspace_script_location = path.getdirectory(wks.script)

        return path.getrelative(workspace_script_location, project_script_location)
    end


---
-- Assemble the list of links just the way Visual Studio likes them.
--
-- @param cfg
--    The active configuration.
-- @param explicit
--    True to explicitly include sibling project libraries; if false Visual
--    Studio's default implicit linking will be used.
-- @return
--    The list of linked libraries, ready to be used in Visual Studio's
--    AdditionalDependencies element.
---

    function fastbuild.getLinks(cfg, explicit)
        return p.tools.msc.getlinks(cfg, not explicit)
    end

--
-- Translate the system and architecture settings from a configuration
-- into a corresponding Visual Studio identifier. If no settings are
-- found in the configuration, a default value is returned, based on
-- the project settings.
--
-- @param cfg
--    The configuration to translate.
-- @param win32
--    If true, enables the "Win32" symbol. If false, uses "x86" instead.
-- @return
--    A Visual Studio architecture identifier.
--

    function fastbuild.archFromConfig(cfg, win32)
        local isnative = project.isnative(cfg.project)

        local arch = architecture(cfg.system, cfg.architecture)
        if not arch then
            arch = iif(isnative, "x86", "Any CPU")
        end

        if win32 and isnative and arch == "x86" then
            arch = "Win32"
        end

        return arch
    end

--
-- Attempt to translate a platform identifier into a corresponding
-- Visual Studio architecture identifier.
--
-- @param platform
--    The platform identifier to translate.
-- @return
--    A Visual Studio architecture identifier, or nil if no mapping
--    could be made.
--

    function fastbuild.archFromPlatform(platform)
        local system = p.api.checkValue(p.fields.system, platform)
        local arch = p.api.checkValue(p.fields.architecture, platform)
        return architecture(system, arch or platform:lower())
    end


--
-- Returns a project configuration name corresponding to the given
-- Premake configuration. This is just the solution build configuration
-- and platform identifiers concatenated.
--

    function fastbuild.projectPlatform(cfg, join)
        if not join then join = "_" end

        local buildConfigurationName = f.removeWhiteSpaces(cfg.buildcfg)
        local platform = cfg.platform
        if platform then
            local pltarch = fastbuild.archFromPlatform(cfg.platform) or platform
            local cfgarch = fastbuild.archFromConfig(cfg)
            -- if pltarch == cfgarch then
            --     platform = nil
            -- end
        end

        if platform then
            return buildConfigurationName .. join .. platform
        else
            return buildConfigurationName
        end
    end

    function fastbuild.projectTargetname(prj, cfg)
        local platform = fastbuild.projectPlatform(cfg, "-")
        return prj.name .. "-" .. platform
    end

--
-- Determine the appropriate Visual Studio platform identifier for a
-- solution-level configuration.
--
-- @param cfg
--    The configuration to be identified.
-- @return
--    A corresponding Visual Studio platform identifier.
--

    function fastbuild.solutionPlatform(cfg)
        local platform = cfg.platform

        -- if a platform is specified use it, translating to the corresponding
        -- Visual Studio identifier if appropriate
        local platarch
        if platform then
            platform = fastbuild.archFromPlatform(platform) or platform

            -- Value for 32-bit arch is different depending on whether this solution
            -- contains C++ or C# projects or both
            if platform ~= "x86" then
                return platform
            end
        end

        -- scan the contained projects to identify the platform
        local hasnative = false
        local hasnet = false
        local slnarch
        for prj in p.workspace.eachproject(cfg.workspace) do
            hasnative = hasnative or project.isnative(prj)
            hasnet    = hasnet    or project.isdotnet(prj)

            -- get a VS architecture identifier for this project
            local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
            if prjcfg then
                local prjarch = fastbuild.archFromConfig(prjcfg)
                if not slnarch then
                    slnarch = prjarch
                elseif slnarch ~= prjarch then
                    slnarch = "Mixed Platforms"
                end
            end
        end


        if platform then
            return iif(hasnet, "x86", "Win32")
        elseif slnarch then
            return iif(slnarch == "x86" and not hasnet, "Win32", slnarch)
        elseif hasnet and hasnative then
            return "Mixed Platforms"
        elseif hasnet then
            return "Any CPU"
        else
            return "Win32"
        end
    end

--
-- Attempt to determine an appropriate Visual Studio architecture identifier
-- for a solution configuration.
--
-- @param cfg
--    The configuration to query.
-- @return
--    A best guess at the corresponding Visual Studio architecture identifier.
--

    function fastbuild.solutionArch(cfg)
        local hasnative = false
        local hasdotnet = false

        -- if the configuration has a platform identifier, use that as default
        local arch = cfg.platform

        -- if the platform identifier matches a known system or architecture,
        --

        for prj in p.workspace.eachproject(cfg.workspace) do
            hasnative = hasnative or project.isnative(prj)
            hasnet    = hasnet    or project.isdotnet(prj)

            if hasnative and hasdotnet then
                return "Mixed Platforms"
            end

            if not arch then
                local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
                if prjcfg then
                    if prjcfg.architecture then
                        arch = fastbuild.archFromConfig(prjcfg)
                    end
                end
            end
        end

        -- use a default if no other architecture was specified
        arch = arch or iif(hasnative, "Win32", "Any CPU")
        return arch
    end


--
-- Returns the Visual Studio solution configuration identifier corresponding
-- to the given Premake configuration.
--
-- @param cfg
--    The configuration to query.
-- @return
--    A solution configuration identifier of the format BuildCfg|Platform,
--    corresponding to the Premake values of the same names. If no platform
--    was specified by the script, the architecture is used instead.
--

    function fastbuild.solutionConfig(cfg, join)
        if not join then join = "_" end
        local platform = cfg.platform

        -- if no platform name was specified, use the architecture instead;
        -- since architectures are defined in the projects and not at the
        -- solution level, need to poke around to figure this out
        if not platform then
            platform = fastbuild.solutionArch(cfg)
        end

        return string.format("%s%s%s", f.removeWhiteSpaces(cfg.buildcfg), join, platform)
    end
