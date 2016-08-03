-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


-- An action is only performed if the clause is true
-- is_valid and update_knowledge will be called regardless though and should
-- keep the truth value into account

local Set = require 'pl.Set'
local List = require 'pl.List'
local tablex = require 'pl.tablex'

local babi = require 'babi._env'

local DIRECTIONS = Set{'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw', 'u', 'd'}
local NUMERIC_RELATIONS = {'size', 'x', 'y', 'z'}
local OPPOSITE_DIRECTIONS = {n='s', ne='sw', e='w', se='nw', s='n',
                             sw='ne', w='e', nw='se', u='d', d='u'}


do
    local Action = torch.class('babi.Action', babi)

    function Action:__tostring()
        return torch.type(self)
    end
end

do
    local Get = torch.class('babi.Get', 'babi.Action', babi)

    function Get:is_valid(world, a0, a1, a2, a3)
        -- We must have an actor getting something
        if not (a0 and a0.is_actor and a1 and a1.is_thing) then
            return false
        elseif not (a1.is_gettable and a0:can_hold(a1)) then
            return false
        end
        if a2 then
            -- Get something from an object in current location.
            if (a2 == 'from' and a3 and a3.is_thing) then
                if a0.is_in ~= a3.is_in or a3.is_in == a0 then
                    return false
                elseif not a1.is_in == a3 then
                    return false
                end
            elseif not (a2 == 'count' and tonumber(a3)) then
                return false
            end
        else
            -- Get something from current location.
            if a0.is_in ~= a1.is_in then
                return false
            end
        end
        return true
    end

    function Get:perform(world, a0, a1, a2, a3)
        a1.is_in = a0
        a0.carry = a0.carry + a1.size
        if a2 == 'from' then
            a3.carry = a3.carry - a1.size
        end
    end

    function Get:update_knowledge(world, knowledge, clause, a0, a1)
        if clause.truth_value then
            -- We now know the a0 is holding this a1.
            knowledge[a1]:set('is_in', a0, true, Set{clause})
        end
    end
end

do
    local Drop = torch.class('babi.Drop', 'babi.Action', babi)

    function Drop:is_valid(world, a0, a1)
        if not (a1 and a0.is_actor and a1 and a1.is_thing) then
            return false
        elseif a1.is_in ~= a0 then
            return false
        end
        return true
    end

    function Drop:perform(world, a0, a1)
        a1.is_in = a0.is_in
        a0.carry = a0.carry - a1.size
    end

    -- TODO What about: "John did not drop the milk." If we allow this when John
    -- is actually not holding the milk, "John did not drop the milk" adds no
    -- information. If we only allow negations of possible actions, this tells
    -- us that John is holding the milk.

    function Drop:update_knowledge(world, knowledge, clause, a0, a1)
        if clause.truth_value then
            if knowledge[a0] and knowledge[a0]['is_in'] then
                -- The object is in the same place where the dropper is
                knowledge[a1]:rawset(
                    'is_in', knowledge[a0]['is_in'], Set{clause}
                )
            else
                -- We just don't know where the object is
                knowledge[a1]:rawset('is_in', List())
            end
        end
    end
end

do
    local Create = torch.class('babi.Create', 'babi.Action', babi)

    function Create:is_valid(world, a0, a1)
        if not (a0 and a0.is_god) or world.entities[a1] then
            return false
        else
            return true
        end
    end

    function Create:perform(world, a0, a1)
        world:create_entity(a1)
    end
end

do
    local SetProperty = torch.class('babi.SetProperty', 'babi.Action', babi)

    function SetProperty:is_valid(world, actor, a0, rel, a1)
        if not (actor and actor.is_god and a0 and rel) then
            return false
        elseif NUMERIC_RELATIONS[rel] and not tonumber(a1) then
            return false
        else
            return true
        end
    end

    function SetProperty:perform(world, actor, a0, rel, a1)
        a1 = a1 or true
        a1 = tonumber(a1) or a1
        if rel == 'is_in' then
            if a0.is_in then
                a0.is_in.carry = a0.is_in.carry - a0.size
            end
            a1.carry = a1.carry + a0.size
        end
        a0[rel] = a1
    end

    function SetProperty:update_knowledge(world, knowledge, clause,
                                          actor, a0, rel, a1)
        knowledge[a0]:set(rel, a1, clause.truth_value, Set{clause})
    end
end

do
    local SetDir = torch.class('babi.SetDir', 'babi.Action', babi)

    function SetDir:is_valid(world, actor, a0, dir, a1)
        if not (actor and actor.is_god) then
            return false
        elseif not (a0 and a0.is_thing and a1 and a1.is_thing) then
            return false
        elseif not DIRECTIONS[dir] then
            return false
        elseif not (a0.x and a1.x and a0.y and a1.y and a0.z and a1.z) then
            return false
        end
        local dx = a1.x - a0.x
        local dy = a1.y - a0.y
        local dz = a1.z - a0.z
        local good = true
        for i = 1, dir:len() do
            local p = dir:sub(i, i)
            if p == 'n' then good = dy > 0; end
            if p == 's' then good = dy < 0; end
            if p == 'e' then good = dx > 0; end
            if p == 'w' then good = dx < 0; end
            if p == 'u' then good = dz > 0; end
            if p == 'd' then good = dz < 0; end
        end
        return good
    end

    function SetDir:perform(world, actor, a0, dir, a1)
        local opposite_dir = OPPOSITE_DIRECTIONS[dir]
        a0[dir] = a1
        a1[opposite_dir] = a0
    end

    function SetDir:update_knowledge(
        world, knowledge, clause, actor, a0, dir, a1
    )
        if clause.truth_value then
            knowledge[a0]:add(dir, a1, true, Set{clause})
            knowledge[a1]:add(dir, a0, true, Set{clause})
        end
    end
end

do
    local SetPos = torch.class('babi.SetPos', 'babi.Action', babi)

    function SetPos:is_valid(world, actor, a0, x, y, z)
        if not (actor and actor.is_god and a0 and x and y) then
            return false
        end
        return true
    end

    function SetPos:perform(world, actor, a0, x, y, z)
        a0.x = x
        a0.y = y
        a0.z = z or 0
    end

    function SetPos:update_knowledge(
        world, knowledge, clause, actor, a0, x, y, z
    )
        knowledge[a0]:set('x', x, true, Set{clause})
        knowledge[a0]:set('y', y, true, Set{clause})
        knowledge[a0]:set('z', z or 0, true, Set{clause})
    end
end

do
    local Teleport = torch.class('babi.Teleport', 'babi.Action', babi)

    function Teleport:is_valid(world, a0, a1)
        if not (a0 and a0.is_actor and a0.is_god) then
            return false
        elseif not (a1 and a1.is_thing) or a0.is_in == a1 then
            return false
        else
            return true
        end
    end

    function Teleport:perform(world, a0, a1)
        if a0.is_in then
            a0.is_in.carry = a0.is_in.carry - a0.size
        end
        a0.is_in = a1
        a1.carry = a1.carry + a0.size
    end

    function Teleport:update_knowledge(world, knowledge, clause, a0, a1)
        if clause.truth_value then
            knowledge[a0]:set('is_in', a1, true, Set{clause})
        end
    end
end

do
    local Give = torch.class('babi.Give', 'babi.Action', babi)

    function Give:is_valid(world, actor, object, recipient)
        if actor.is_in ~= recipient.is_in or actor == recipient then
            return false
        elseif object.is_in ~= actor then
            return false
        else
            return true
        end
    end

    function Give:perform(world, actor, object, recipient)
        object.is_in = recipient
    end

    function Give:update_knowledge(world, knowledge, clause,
                                   actor, object, recipient)
        knowledge[object]:set('is_in', recipient, Set{clause})

        local current_knowledge = {}
        for _, entity in ipairs{actor, recipient, object} do
            if knowledge[entity]['is_in'] then
                current_knowledge[entity] =
                    tablex.deepcopy(knowledge[entity]['is_in'])
            else
                current_knowledge[entity] = List()
            end
        end

        knowledge[actor]:merge(
            'is_in', current_knowledge[recipient], Set{clause}
        )
        knowledge[recipient]:merge(
            'is_in', current_knowledge[actor], Set{clause}
        )
    end
end

return {
    get=babi.Get, drop=babi.Drop, give=babi.Give, teleport=babi.Teleport,
    create=babi.Create, set=babi.SetProperty, set_dir=babi.SetDir,
    set_pos=babi.SetPos
}
