--
-- actions/fastbuild/fastbuild.lua
-- Extend the existing exporters with support for FASTBuild
-- Copyright (c) 2017-2017 Daniel Penkała 
--

    local p = premake

    -- initialize module.
    p.modules.fastbuild = p.modules.fastbuild or {}
    p.modules.fastbuild._VERSION = p._VERSION
    p.fastbuild = p.modules.fastbuild

    -- load actions.
    require "fastbuild_action"
    require "fastbuild_utils"
    require "fastbuild_platforms"
    require "fastbuild_toolset"
    require "fastbuild_solution"
    require "fastbuild_project"
