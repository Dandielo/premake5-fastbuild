--
-- actions/fastbuild/fastbuild.lua
-- Extend the existing exporters with support for FASTBuild
-- Copyright (c) 2017-2017 Daniel Penkała 
--

    local p = premake
    p.fastbuild.dependency_resolver = { }

    local tree = p.tree
    local project = p.project
    local workspace = p.workspace

    local m = p.fastbuild.dependency_resolver

---
-- Calls the function for each project in the workspace in dependency relative order 
---
    
    m.resolved = { }
    
    function m.eachproject(wks, func)
        if not m.resolved[wks.name] then 
            m.resolved[wks.name] = m.projectsResolved(wks)
        end

        for _, prj in pairs(m.resolved[wks.name]) do 
            func(prj)
        end
    end


---
-- Removes duplicate entries from a list, always pushing the first occurance into the resulting list
---
    local function remove_duplicates(list)
        local helper = { }
        local result_list = { }

        for _, prj in pairs(list) do 
            if not helper[prj] then
                helper[prj] = true
                table.insert(result_list, prj)
            end
        end

        return result_list
    end

---
-- Returns a list of projects in dependency relative order 
---
    function m.projectsResolved(wks)
        local projects_list = { }

        local tr = workspace.grouptree(wks)

        -- Traverse the tree and append each project and its dependencies to a list. (dependiencies go first)
        tree.traverse(tr, { 
            onleaf = function(node)
                local proj = node.project
                local dependencies = project.getdependencies(proj, 'all')

                -- Add each dependency to the list
                table.foreachi(dependencies, function(dependency)
                    table.insert(projects_list, dependency)
                end)

                -- Add the project itself as last element
                table.insert(projects_list, proj)
            end
        })

        -- Remove duplicates
        return remove_duplicates(projects_list)
    end
