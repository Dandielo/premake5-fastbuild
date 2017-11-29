---
-- fastbuild_compiler.lua
-- Work with the list of toolsets loaded from the script.
-- Copyright (c) 2017-2017 Daniel Penkała 
---

    local p = premake
    local fbuild = p.fastbuild
    fbuild.toolsets = { }

    local toolsets = p.fastbuild.toolsets
    local m = p.fastbuild.toolsets


---
-- Compiler elements available in fastbuild 
---

    m.elements = { }
    m.elements.toolsets = { }


---
-- Create a new compiler container instance.
--- 

    function m.findToolsets(name, wks)
        local toolsets = { }
        p.callArray(m.elements.toolsets, toolsets, wks)
        return toolsets
    end


---
-- General compiler info
---
    
    m.elements.toolsets = function(name, wks)
        if (os.ishost and os.ishost("windows")) or os.is("Windows") then 
            return { 
                m.locateToolsetsVisualStudio,
            }
        else
            assert("Not supported yet!")
        end
    end

---
-- Path definition
---
    local function replaceTokens(strings, tokens)
        local result = {}
        for k, v in pairs(strings) do
            result[k] = v
        end

        for k, v in pairs(result) do 
            result[k] = v:gsub("%{(.-)%}", function(arg)
                return tokens[arg]
            end)

            result[k] = path.translate(result[k])
        end
        return result
    end

    local function getWindowsSDKDefaultVersion()
        local reg_arch = iif(os.is64bit(), "\\Wow6432Node\\", "\\")
        return os.getWindowsRegistry and os.getWindowsRegistry("HKLM:SOFTWARE" .. reg_arch .."Microsoft\\Microsoft SDKs\\Windows\\v10.0\\ProductVersion") or "8.1" -- fallback SDK
    end

    local function getVisualStudioDefaultVersion(base_path, type)
        local version
        f = io.open(base_path .. "\\VC\\Auxiliary\\Build\\Microsoft.VC" .. type .. "Version.default.txt")
        if f then
            version = f:read("*l"):gsub(" ", "")
            f:close()
        end
        return version
    end

    local function getWindowsSDKBaseDirectories(version)
        local major = tonumber(version:gmatch("%d+")())
        if major <= 8 then 
            return { 
                include = path.translate("C:/Program Files (x86)/Windows Kits/" .. version .. "/Include"),
                lib = path.translate("C:/Program Files (x86)/Windows Kits/" .. version .. "/Lib/winv6.3"),
            }
        else 
            return { 
                include = path.translate("C:/Program Files (x86)/Windows Kits/" .. major .. "/Include/" .. version),
                lib = path.translate("C:/Program Files (x86)/Windows Kits/" .. major .. "/Lib/" .. version),
            }
        end
    end

    function m.locateToolsetsVisualStudio(list, wks)
        list.msc141 = { }

        local toolset = list.msc141         
        toolset.VSBasePath = path.translate('C:/Program Files (x86)/Microsoft Visual Studio/2017/Professional')

        if not os.isdir(toolset.VSBasePath) then 
            toolset.VSBasePath = path.translate('C:/Program Files (x86)/Microsoft Visual Studio/2017/Community')
            assert(os.isdir(toolset.VSBasePath))
        end


        toolset.WindowsSDKBasePath = path.translate('C:/Program Files (x86)/Microsoft SDKs/Windows/v7.0A')

        local tools_version = getVisualStudioDefaultVersion(toolset.VSBasePath, "Tools")
        local redist_version = getVisualStudioDefaultVersion(toolset.VSBasePath, "Redist")
        local winsdk_version = getWindowsSDKDefaultVersion()

        toolset.x64VSBinBasePath = path.translate(('$VSBasePath$/VC/Tools/MSVC/%s/bin/HostX64/x64'):format(tools_version))
        toolset.x86VSBinBasePath = path.translate(('$VSBasePath$/VC/Tools/MSVC/%s/bin/HostX64/x86'):format(tools_version))

        local vs_dirs = { 
            '$VSBasePath$/VC/Tools/MSVC/{tools_version}/{type}{arch}',
            '$VSBasePath$/VC/Tools/MSVC/{tools_version}/atlmfc/{type}{arch}',
            '$VSBasePath$/VC/Auxiliary/VS/{type}{arch}',
            '$VSBasePath$/VC/Auxiliary/VS/UnitTest/{type}',
        }

        local winsdk_dirs = getWindowsSDKBaseDirectories(winsdk_version)

        local win_include_dirs = {
            winsdk_dirs.include .. '/um',
            winsdk_dirs.include .. '/shared',
            winsdk_dirs.include .. '/winrt',
        }

        local win_lib_dirs = {
            winsdk_dirs.lib .. '/um/{arch}',
        }

        local extra_files = {
            '${arch}VSBinBasePath$/c1.dll',
            -- '${arch}VSBinBasePath$/c1ast.dll',
            '${arch}VSBinBasePath$/c1xx.dll',
            -- '${arch}VSBinBasePath$/c1xxast.dll',
            '${arch}VSBinBasePath$/c2.dll',
            '${arch}VSBinBasePath$/msobj140.dll',
            '${arch}VSBinBasePath$/mspdb140.dll',
            '${arch}VSBinBasePath$/mspdbcore.dll',
            '${arch}VSBinBasePath$/mspdbsrv.exe',
            '${arch}VSBinBasePath$/mspft140.dll',
            '${arch}VSBinBasePath$/1033/clui.dll',
            '$VSBasePath$/VC/Redist/MSVC/{redist_version}/{arch}/Microsoft.VC141.CRT/msvcp140.dll',
            '$VSBasePath$/VC/Redist/MSVC/{redist_version}/{arch}/Microsoft.VC141.CRT/concrt140.dll',
            -- '$VSBasePath$/VC/Redist/MSVC/{redist_version}/{arch}/Microsoft.VC141.CRT/msvcr140.dll',
            '$VSBasePath$/VC/Redist/MSVC/{redist_version}/{arch}/Microsoft.VC141.CRT/vccorlib140.dll',
            '$VSBasePath$/VC/Redist/MSVC/{redist_version}/{arch}/Microsoft.VC141.CRT/vcruntime140.dll',
        }



        toolset.x64VSIncludeDirs = replaceTokens(vs_dirs, { tools_version = tools_version, type = "include", arch = "" })
        toolset.x86VSIncludeDirs = replaceTokens(vs_dirs, { tools_version = tools_version, type = "include", arch = "" })

        table.insert(toolset.x64VSIncludeDirs, path.translate('C:/Program Files (x86)/Windows Kits/10/Include/10.0.10240.0/ucrt'))
        table.insert(toolset.x86VSIncludeDirs, path.translate('C:/Program Files (x86)/Windows Kits/10/Include/10.0.10240.0/ucrt'))

        toolset.x64VSIncludeDirs = table.join(toolset.x64VSIncludeDirs, replaceTokens(win_include_dirs, { }))
        toolset.x86VSIncludeDirs = table.join(toolset.x86VSIncludeDirs, replaceTokens(win_include_dirs, { }))



        toolset.x64VSLibDirs = replaceTokens(vs_dirs, { tools_version = tools_version, type = "lib", arch = "/x64" })
        toolset.x86VSLibDirs = replaceTokens(vs_dirs, { tools_version = tools_version, type = "lib", arch = "/x86" })

        table.insert(toolset.x64VSLibDirs, path.translate('C:/Program Files (x86)/Windows Kits/10/lib/10.0.10240.0/ucrt/x64'))
        table.insert(toolset.x86VSLibDirs, path.translate('C:/Program Files (x86)/Windows Kits/10/lib/10.0.10240.0/ucrt/x86'))

        toolset.x64VSLibDirs = table.join(toolset.x64VSLibDirs, replaceTokens(win_lib_dirs, { arch = "x64" }))
        toolset.x86VSLibDirs = table.join(toolset.x86VSLibDirs, replaceTokens(win_lib_dirs, { arch = "x86" }))



        toolset.x64CompilerExtraFiles = replaceTokens(extra_files, { redist_version = redist_version, arch = "x64" })
        toolset.x86CompilerExtraFiles = replaceTokens(extra_files, { redist_version = redist_version, arch = "x86" })

        toolset.Compiler = "cl.exe"
        toolset.Linker = "link.exe"
        toolset.Librarian = "lib.exe"
        toolset.Assembly = "ml64.exe"
    end

    function m.compiler(name, wks)
        return function(info)
            info.name = name
            info.compiler = "cl.exe"
            info.linker = "link.exe"
        end
    end

    function m.compilerBasepath(name, wks)
        local basepath = ""
        if name == "vs2017" then 
            basepath = "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Professional"

            local version
            f = io.open(basepath .. "\\VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt")
            if f then
                version = f:read("*l"):gsub(" ", "")
                f:close()
            end

            local architecture_map = { x86_64 = "x64" }
            basepath = basepath .. "\\VC\\Tools\\MSVC\\" .. version .. "\\bin\\HostX64\\" .. architecture_map[wks.architecture] or "x86"
        end

        return function(info)
            info.path = basepath
        end
    end
