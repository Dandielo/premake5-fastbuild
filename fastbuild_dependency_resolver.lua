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


        -- local projects = { 
        --     list = { },
        --     paths = { },
        --     groups = { [""] = { } },
        --     groups_stack = { "" },
        --     group_current = ""
        -- }

        -- function projects.onleaf(self)
        --     return function(n)
        --         local prj = n.project

        --         -- Build a relative path from the solution file to the project file
        --         local prjpath = p.filename(prj, ".prj.bff")
        --         prjpath = fastbuild.path(prj.workspace, prjpath)

        --         -- Sort by dependencies 
        --         self:add(prj, prjpath)

        --         -- p.x('#include "%s"', prjpath)
        --         -- sln2005.projectdependencies(prj)
        --     end
        -- end

        -- function projects.onbranch(self)
        --     return function(n)
        --         self.current_group = n.name
        --         self.groups[n.name] = self.groups[n.name] or { }
        --         table.insert(self.groups_stack, n.name)
        --     end
        -- end

        -- function projects.onbranchexit(self)
        --     return function()
        --         table.remove(self.groups_stack, #self.groups_stack)
        --         self.current_group = self.groups_stack[#self.groups_stack]
        --     end
        -- end

        -- function projects.add(self, prj, path)
        --     local refs = project.getdependencies(prj, 'all')
        --     for _, ref in pairs(refs or { }) do
        --         self:add(ref)
        --     end

        --     if path and not self.paths[prj.name] then 
        --         self.paths[prj.name] = path
        --         table.insert(self.groups[self.current_group], prj.name)
        --     end

        --     table.insert(self.list, prj)
        -- end

        -- function projects.remove_duplicates(self)
        --     local found = { }
        --     local sorted = { }
        --     for _, prj in pairs(self.list) do 
        --         if not found[prj.name] then
        --             found[prj.name] = prj
        --             table.insert(sorted, prj)
        --         end
        --     end
        --     self.list = sorted
        -- end

        -- function projects.for_each(self, func)
        --     for _, prj in pairs(self.list) do 
        --         func(prj, self.paths[prj.name])
        --     end
        -- end

        -- function projects.for_each_group(self, func)
        --     for key, prjs in pairs(self.groups) do 
        --         func(key, prjs)
        --     end
        -- end
