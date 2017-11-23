--
-- _preload.lua
-- Define the makefile action(s).
-- Copyright (c) 2017-2017 Daniel Penkała 
--

    local p = premake
    local project = p.project

    -- initialize module.
    p.modules.fastbuild = p.modules.fastbuild or {}
    p.modules.fastbuild._VERSION = p._VERSION
    p.fastbuild = p.modules.fastbuild

    -- load actions.
    include("fastbuild.lua")

--
-- Decide when the full module should be loaded.
--

    return function(cfg)
        return _ACTION == "fastbuild"
    end
