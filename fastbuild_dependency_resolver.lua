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
    m.resolved = { }
    m.groups = { }

---
-- Calls the function for each project in the workspace in dependency relative order
---


    function m.eachproject(wks, func)
        for _, prj in pairs(m.allprojects(wks)) do
            func(prj)
        end
    end

    function m.eachgroup(wks, func)
        for _, prj in pairs(m.allgroups(wks)) do
            func(name, group)
        end
    end


---
-- Returns a list of projets in dependency relative order
---
    function m.allprojects(wks)
        if not m.resolved[wks.name] then
            m.resolved[wks.name] = m.projectsResolved(wks)
        end

        return m.resolved[wks.name]
    end

    function m.allgroups(wks)
        if not m.groups[wks.name] then
            m.groups[wks.name] = m.groupsResolved(wks)
        end

        return m.groups[wks.name]
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
-- Given a project add it and all it's dependencies to the given list starting with it's dependencies
---
    local function add_project_to_list(list, proj)
        local dependencies = project.getdependencies(proj, 'all')

        table.foreachi(dependencies, function(dependency)
            add_project_to_list(list, dependency)
        end)

        table.insert(list, proj)
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
                add_project_to_list(projects_list, proj)
            end,
        })

        -- Remove duplicates
        return remove_duplicates(projects_list)
    end

---
-- Returns a list of projects in dependency relative order
---
    function m.groupsResolved(wks)
        local solution_groups = { }
        local groups_stack = { "" }
        local current_group_at = 1

        local function current_group()
            return groups_stack[current_group_at]
        end

        -- Default group
        solution_groups[current_group()] = { }

        local tr = workspace.grouptree(wks)

        -- Traverse the tree and append each project and its dependencies to a list. (dependiencies go first)
        tree.traverse(tr, {
            onleaf = function(node)
                table.insert(solution_groups[current_group()], node.project)
            end,
            onbranchenter = function(node, depth)
                local group_name = current_group() .. "/" .. node.name
                solution_groups[group_name] = solution_groups[group_name] or { }

                current_group_at = current_group_at + 1
                groups_stack[current_group_at] = group_name
            end,
            onbranchexit = function(node, depth)
                current_group_at = current_group_at - 1
            end
        })

        -- For each group
        local result_groups = { }
        for name, group in pairs(solution_groups) do
            if name ~= "" then
                name = name:sub(2)
            end

            table.insert(result_groups, {
                name = name,
                projects = group
            })
        end

        -- Sort the table
        table.sort(result_groups, function(g1, g2)
            return g1.name < g2.name
        end)

        -- Remove duplicates
        return result_groups
    end
