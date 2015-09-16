-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local utilities = require 'babi.utilities'

local class = require 'class'

local tablex = require 'pl.tablex'
local stringx = require 'pl.stringx'
local List = require 'pl.List'
local Set = require 'pl.Set'

local DEBUG_LEVEL = 0

local DIRECTIONS = Set{'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw', 'u', 'd'}
local OPPOSITE_DIRECTIONS = {n='s', ne='sw', e='w', se='nw', s='n',
                             sw='ne', w='e', nw='se', u='d', d='u'}
local FULL_DIRECTIONS = {
    cardinal={
        n='north',s='south',e='east',w='west'
    },
    relative={
        n='above', s='below',
        e='to the left of', w='to the right of'
    }
}
local NUMERALS = {
    [0]='zero', [1]='one', [2]='two', [3]='three', [4]='four', [5]='five',
    [6]='six', [7]='seven', [8]='eight', [9]='nine', [10]='ten', [11]='eleven',
    [12]='twelve', [13]='thirteen', [14]='fourteen', [15]='fifteen',
    [16]='sixteen', [17]='seventeen', [18]='eighteen', [19]='nineteen',
    [20]='twenty', [21]='twenty-one', [22]='twenty-two', [23]='twenty-three',
    [24]='twenty-four', [25]='twenty-five', [26]='twenty-six',
    [27]='twenty-seven', [28]='twenty-eight', [29]='twenty-nine',
    [30]='thirty', [31]='thirty-one', [32]='thirty-two', [33]='thirty-three',
    [34]='thirty-four', [35]='thirty-five', [36]='thirty-six',
    [37]='thirty-seven', [38]='thirty-eight', [39]='thirty-nine', [40]='forty',
    [41]='forty-one', [42]='forty-two', [43]='forty-three', [44]='forty-four',
    [45]='forty-five', [46]='forty-six', [47]='forty-seven',
    [48]='forty-eight', [49]='forty-nine', [50]='fifty', [51]='fifty-one',
    [52]='fifty-two', [53]='fifty-three', [54]='fifty-four', [55]='fifty-five',
    [56]='fifty-six', [57]='fifty-seven', [58]='fifty-eight',
    [59]='fifty-nine', [60]='sixty', [61]='sixty-one', [62]='sixty-two',
    [63]='sixty-three', [64]='sixty-four', [65]='sixty-five', [66]='sixty-six',
    [67]='sixty-seven', [68]='sixty-eight', [69]='sixty-nine', [70]='seventy',
    [71]='seventy-one', [72]='seventy-two', [73]='seventy-three',
    [74]='seventy-four', [75]='seventy-five', [76]='seventy-six',
    [77]='seventy-seven', [78]='seventy-eight', [79]='seventy-nine',
    [80]='eighty', [81]='eighty-one', [82]='eighty-two', [83]='eighty-three',
    [84]='eighty-four', [85]='eighty-five', [86]='eighty-six',
    [87]='eighty-seven', [88]='eighty-eight', [89]='eighty-nine',
    [90]='ninety', [91]='ninety-one', [92]='ninety-two', [93]='ninety-three',
    [94]='ninety-four', [95]='ninety-five', [96]='ninety-six',
    [97]='ninety-seven', [98]='ninety-eight', [99]='ninety-nine'
}
local PUNCTUATION = Set{'.', '?', '!'}

local function _combinations(list, pool)
    local new_list = list:clone()
    for i = 1, #pool[1] do
        for j = 1, #list do
            new_list[(i - 1) * #list + j] = list[j] .. pool[1][i]
        end
    end
    if #pool > 1 then
        return _combinations(new_list, pool:slice(2))
    else
        return new_list
    end
end

local function is_property_clause(clause, property)
        if class.istype(clause, 'Clause') and
            class.istype(clause.action, 'SetProperty') and
            clause.args[2] == property then
        return true
    end
end

-- All possible combinations of sets of strings
local function combinations(...)
    return _combinations(List{''}, List{...})
end

-- Templates match a set of clauses and turn them into text

local Template = class('Template')

function Template:__init(i, j, story, knowledge, config,
                         mentions, coreferences)
    self.i = i
    self.j = j
    self.story = story
    self.knowledge = knowledge
    self.config = config
    self.mentions = mentions
    self.coreferences = coreferences
end

function Template:cast(template)
    return template(self.i, self.j, self.story, self.knowledge, self.config,
                    self.mentions, self.coreferences)
end

function Template:add_mentions()
    return
end

function Template:add_coreferences()
    return
end

function Template:clause(i)
    i = i or self.i
    return self.story[i]
end

function Template:render_symbolic()
    return {'NO SYMBOLIC TEMPLATE'}
end

-- A base class for templates that render a single clause with a single actor

local Simple = class('Simple', 'Template')

Simple.clauses = 1

function Simple:add_mentions()
    self.mentions[self.j] = List{self:clause().actor}
end

local SimpleGet = class('SimpleGet', 'Simple')

function SimpleGet:__init(...)
    Template.__init(self, ...)
end

function SimpleGet:is_valid()
    if class.istype(self:clause().action, 'Get') and
            not self:clause().args[2] then
        return true
    end
end

function SimpleGet:render(actor)
    actor = actor or self:clause().actor.name
    local templates = {
        '%s grabbed the %s',
        '%s took the %s',
        '%s got the %s'
    }
    return tablex.map(string.format, templates,
                      actor, self:clause().args[1].name)
end

local CountGet = class('CountGet', 'Simple')

function CountGet:__init(...)
    Template.__init(self, ...)
end

function CountGet:is_valid()
    if class.istype(self:clause().action, 'Get') and
            self:clause().args[2] == 'count' then
        return true
    end
end

function CountGet:render()
    local templates = {
        '%s grabbed %s %s',
        '%s took %s %s',
        '%s got %s %s'
    }
    local count = self:clause().args[3]
    return tablex.map(
        string.format,
        count == 1 and templates or combinations(templates, {'s'}),
        self:clause().actor.name, NUMERALS[count], self:clause().args[1].name
    )
end

local BuyGet = class('BuyGet', 'Simple')

function BuyGet:__init(...)
    Template.__init(self, ...)
end

function BuyGet:is_valid()
    if class.istype(self:clause().action, 'Get') and
            self:clause().args[2] == 'buy' then
        return true
    end
end

function BuyGet:render()
    local templates = {
        '%s bought %s %s',
        '%s purchased %s %s',
        '%s paid for %s %s'
    }
    local count = self:clause().args[3]
    return tablex.map(
        string.format,
        count == 1 and templates or combinations(templates, {'s'}),
        self:clause().actor.name, NUMERALS[count], self:clause().args[1].name
    )
end

local SimpleTeleport = class('SimpleTeleport', 'Simple')

local CoreferenceTeleport = class('CoreferenceTeleport', 'Simple')

local CompoundCoreferenceTeleport = class('CompoundCoreferenceTeleport',
                                          'Template')

local ConjunctionTeleport = class('ConjunctionTeleport', 'Template')

function SimpleTeleport:__init(...)
    Template.__init(self, ...)
end

function SimpleTeleport:is_valid()
    if class.istype(self:clause().action, 'Teleport') and
            not self:cast(CoreferenceTeleport):is_valid() and
            not self:cast(ConjunctionTeleport):is_valid() and
            not self:cast(CompoundCoreferenceTeleport):is_valid() then
        return true
    end
end

function SimpleTeleport:render(actor)
    actor = actor or self:clause().actor.name
    local before, after = '', ''
    if self:clause().args[2] == 'when' then
        after = self:clause().args[3]
        if math.random(2) == 1 then
            before, after = after, before
        end
    end
    local templates = {
        '%s went to the %s',
        '%s journeyed to the %s',
        '%s travelled to the %s',
        '%s moved to the %s',
    }
    templates = tablex.map(function(t) return stringx.strip(stringx.join(' ', {before, t, after})) end,
                           templates)
    return tablex.map(string.format, templates,
                      actor, self:clause().args[1].name)
end


function CoreferenceTeleport:__init(...)
    Template.__init(self, ...)
end

function CoreferenceTeleport:is_valid()
    if class.istype(self:clause().action, 'Teleport') and
            self.mentions[self.j - 1] == List{self:clause().actor} and
            math.random() < self.config['coreference'] and
            not self:cast(CompoundCoreferenceTeleport):is_valid() then
        return true
    end
end

function CoreferenceTeleport:render()
    local actor = self:clause().actor
    local adverbs = {'after that %s', 'following that %s',
                     'then %s', '%s then'}
    local templates = {
        ' went to the %s',
        ' journeyed to the %s',
        ' travelled to the %s',
        ' moved to the %s',
    }
    return tablex.map(string.format, combinations(adverbs, templates),
                      actor.is_male and 'he' or 'she',
                      self:clause().args[1].name)
end

function CoreferenceTeleport:add_coreferences()
    self.coreferences[self:clause()] = self.story[self.i - 1]
end

CompoundCoreferenceTeleport.clauses = 2

function CompoundCoreferenceTeleport:__init(...)
    Template.__init(self, ...)
end

function CompoundCoreferenceTeleport:is_valid()
    if self.i < #self.story then
        local clauses = self.story:slice(self.i - 2, self.i + 1)
        if math.random() > self.config['coreference'] or
           math.random() > self.config['compound'] then
            return false
        end
        if #clauses == 4 then
            for _, clause in pairs(clauses) do
                if not class.istype(clause.action, 'Teleport') then
                    return false
                end
            end
            local actors1 = Set{clauses[1].actor, clauses[2].actor}
            local actors2 = Set{clauses[3].actor, clauses[4].actor}
            if actors1 == actors2 and
                    clauses[3].args[1] == clauses[4].args[1] then
                return true
            end
        end
    end
end

function CompoundCoreferenceTeleport:add_coreferences()
    self.coreferences[self.story[self.i]] = self.story[self.i - 1]
    self.coreferences[self.story[self.i + 1]] = self.story[self.i - 1]
end

function CompoundCoreferenceTeleport:render()
    local adverbs = {'after that', 'following that', 'then'}
    local templates = {
        ' they went to the %s',
        ' they journeyed to the %s',
        ' they travelled to the %s',
        ' they moved to the %s',
    }
    return tablex.map(string.format, combinations(adverbs, templates),
                      self:clause().args[1].name)
end

local EvalIsIn = class('EvalIsIn', 'Template')

EvalIsIn.clauses = 1

function EvalIsIn:__init(...)
    Template.__init(self, ...)
end

function EvalIsIn:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'eval' and
        is_property_clause(self:clause().args, 'is_in')
end

function EvalIsIn:render()
    local template
    local clause = self:clause().args
    if clause.args[1].is_actor then
        template = 'where is %s?'
    else
        template = 'where is the %s?'
    end
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[3].name)}
end

function EvalIsIn:render_symbolic()
    local template
    local clause = self:clause().args
    return {('%s is_in\t%s'):format(clause.args[1].name,
                                    clause.args[3].name)}
end

local EvalHasFear = class('EvalHasFear', 'Template')

EvalHasFear.clauses = 1

function EvalHasFear:__init(...)
    Template.__init(self, ...)
end

function EvalHasFear:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'eval' and
        is_property_clause(self:clause().args, 'has_fear')
end

function EvalHasFear:render()
    local template = 'what is %s afraid of?'
    local clause = self:clause().args
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[3].name)}
end

function EvalHasFear:render_symbolic()
    local template = '%s has_fear'
    local clause = self:clause().args
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[3].name)}
end

local EvalHasColor = class('EvalHasColor', 'Template')

EvalHasColor.clauses = 1

function EvalHasColor:__init(...)
    Template.__init(self, ...)
end

function EvalHasColor:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'eval' and
        is_property_clause(self:clause().args, 'has_color')
end

function EvalHasColor:render()
    local template = 'what color is %s?'
    local clause = self:clause().args
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[3].name)}
end

function EvalHasColor:render_symbolic()
    local template = '%s has_color'
    local clause = self:clause().args
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[3].name)}
end

local EvalBefore = class('EvalBefore', 'Template')

EvalBefore.clauses = 1

function EvalBefore:__init(...)
    Template.__init(self, ...)
end

function EvalBefore:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'eval' and
        is_property_clause(self:clause().args, 'before')
end

function EvalBefore:render()
    local clause = self:clause().args
    local template = 'where was %s before the %s?'
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[4].name,
                                        clause.args[3].name)}
end

function EvalBefore:render_symbolic()
    local clause = self:clause().args
    local template = '%s is_in before %s'
    return {(template .. '\t%s'):format(clause.args[1].name,
                                        clause.args[4].name,
                                        clause.args[3].name)}
end

local SimpleDrop= class('SimpleDrop', 'Simple')

function SimpleDrop:__init(...)
    Template.__init(self, ...)
end

function SimpleDrop:is_valid()
    if class.istype(self:clause().action, 'Drop') then
        return true
    end
end

function SimpleDrop:render()
    local templates = {
        '%s dropped the %s',
        '%s put down the %s',
        '%s let go of the %s'
    }
    return tablex.map(string.format, templates,
                      self:clause().actor.name, self:clause().args[1].name)
end

local YesNoIsIn = class('YesNoIsIn', 'Template')

function YesNoIsIn:__init(...)
    Template.__init(self, ...)
end

YesNoIsIn.clauses = 1

function YesNoIsIn:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'yes_no' and
        is_property_clause(self:clause().args, 'is_in')
end

function YesNoIsIn:render()
    local template
    local entity, _, location = unpack(self:clause().args.args)
    if entity.is_actor then
        template = 'is %s in the %s?'
    else
        template = 'is the %s in the %s?'
    end
    local truth_value = self:clause().args.truth_value
    local answer
    if truth_value == nil then
        answer = 'maybe'
    else
        answer = truth_value and 'yes' or 'no'
    end
    return {(template .. '\t%s'):format(entity.name, location.name, answer)}
end

function YesNoIsIn:render_symbolic()
    local entity, _, location = unpack(self:clause().args.args)
    local template = '%s is_in %s'
    local truth_value = self:clause().args.truth_value
    local answer
    if truth_value == nil then
        answer = 'unknown'
    else
        answer = truth_value and 'true' or 'false'
    end
    return {(template .. '\t%s'):format(entity.name, location.name, answer)}
end

local WhyTeleport = class('WhyTeleport', 'Template')

function WhyTeleport:__init(...)
    Template.__init(self, ...)
end

WhyTeleport.clauses = 1

function WhyTeleport:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'why' and
        class.istype(self:clause().args[1].action, 'Teleport')
end

function WhyTeleport:render()
    local clause = self:clause().args[1]
    local template = 'why did %s go to the %s?'
    return {(template .. '\t%s'):format(
        clause.actor.name, clause.args[1].name, self:clause().args[2]
    )}
end

function WhyTeleport:render_symbolic()
    local clause = self:clause().args[1]
    return {('%s teleport %s\t%s'):format(
        clause.actor.name, clause.args[1].name, self:clause().args[2]
    )}
end

local WhyGet = class('WhyGet', 'Template')

function WhyGet:__init(...)
    Template.__init(self, ...)
end

WhyGet.clauses = 1

function WhyGet:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'why' and
        class.istype(self:clause().args[1].action, 'Get')
end

function WhyGet:render()
    local clause = self:clause().args[1]
    local template = 'why did %s get the %s?'
    return {(template .. '\t%s'):format(
        clause.actor.name, clause.args[1].name, self:clause().args[2]
    )}
end

function WhyGet:render_symbolic()
    local clause = self:clause().args[1]
    local template = 'why did %s get the %s?'
    return {('%s get %s\t%s'):format(
        clause.actor.name, clause.args[1].name, self:clause().args[2]
    )}
end

local Motivation = class('Motivation', 'Template')

function Motivation:__init(...)
    Template.__init(self, ...)
end

Motivation.clauses = 1

function Motivation:is_valid()
    return class.istype(self:clause(), 'Question') and
        self:clause().kind == 'whereto' and
        class.istype(self:clause().args[1].action, 'SetProperty')
end

function Motivation:render()
    local clause = self:clause().args[1]
    local template = 'where will %s go?'
    return {(template .. '\t%s'):format(
        clause.args[1], self:clause().args[2].destination
    )}
end

function Motivation:render_symbolic()
    local clause = self:clause().args[1]
    return {('teleport %s\t%s'):format(clause.args[1],
                                       self:clause().args[2].destination)}
end

local EvalDir = class('EvalDir', 'Template')

function EvalDir:__init(...)
    Template.__init(self, ...)
end

EvalDir.clauses = 1

function EvalDir:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'eval' then
        for dir, _ in pairs(DIRECTIONS) do
            if is_property_clause(self:clause().args, dir) then
                return true
            end
        end
    end
end

function EvalDir:render()
    local location, dir, target = unpack(self:clause().args.args)
    local full_directions = FULL_DIRECTIONS[self.config.directions]
    local tmpl1 = 'what is %s of the %s?\t%s'
    tmpl1 = tmpl1:format(full_directions[dir],
                         target.name, location.name)

    local tmpl2 = 'what is the %s %s of?\t%s'
    tmpl2 = tmpl2:format(location.name,
                         full_directions[OPPOSITE_DIRECTIONS[dir]],
                         target.name)

    return {tmpl1, tmpl2}
end

function EvalDir:render_symbolic()
    local location, dir, target = unpack(self:clause().args.args)
    return {('%s %s\t%s'):format(location.name, dir, target.name)}
end

local YesNoDir= class('YesNoDir', 'Template')

function YesNoDir:__init(...)
    Template.__init(self, ...)
end

YesNoDir.clauses = 1

function YesNoDir:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'yes_no' then
        for dir, _ in pairs(DIRECTIONS) do
            if is_property_clause(self:clause().args, dir) then
                return true
            end
        end
    end
end

function YesNoDir:render()
    local source, dir, target = unpack(self:clause().args.args)
    local full_directions = FULL_DIRECTIONS[self.config.directions]
    local tmpl1 = 'is the %s %s the %s?\t%s'
    tmpl1 = tmpl1:format(source.name, full_directions[dir], target.name,
                         self:clause().args.truth_value and 'yes' or 'no')
    return {tmpl1}
end

function YesNoDir:render_symbolic()
    local source, dir, target = unpack(self:clause().args.args)
    return {('%s %s %s\t%s'):format(
        source.name, dir, target.name,
        self:clause().args.truth_value and 'true' or 'false'
    )}
end

local Dir = class('Dir', 'Template')

function Dir:__init(...)
    Template.__init(self, ...)
end

Dir.clauses = 1

function Dir:is_valid()
    for dir, _ in pairs(DIRECTIONS) do
        if is_property_clause(self:clause(), dir) then
            return true
        end
    end
end

function Dir:render()
    local loc1, dir, loc2 = unpack(self:clause().args)
    local full_directions = FULL_DIRECTIONS[self.config.directions]
    local tmpl = 'the %s is %s of the %s'
    return {tmpl:format(loc2.name, full_directions[dir], loc1.name),
            tmpl:format(loc1.name,
                        full_directions[OPPOSITE_DIRECTIONS[dir]],
                        loc2.name)}
end

local Syllogism = class('Syllogism', 'Template')

function Syllogism:__init(...)
    Template.__init(self, ...)
end

Syllogism.clauses = 1

function Syllogism:is_valid()
    for _, form in pairs({'A', 'E', 'I', 'O'}) do
        if is_property_clause(self:clause(), form) then
            return true
        end
    end
end

function Syllogism:render()
    local term1, form, term2 = unpack(self:clause().args)
    local templates = ({
        A={'all %s are %s'},
        E={'no %s are %s'},
        I={'some %s are %s'},
        O={'some %s are not %s'}
    })[form]
    return tablex.map(string.format, templates, term1, term2)
end

local EvalSyllogism = class('EvalSyllogism', 'Template')

function EvalSyllogism:__init(...)
    Template.__init(self, ...)
end

EvalSyllogism.clauses = 1

function EvalSyllogism:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'eval' then
        for _, form in pairs({'A', 'E', 'I', 'O'}) do
            if is_property_clause(self:clause().args, form) then
                return true
            end
        end
    end
end

function EvalSyllogism:render()
    local term1, form, term2 = unpack(self:clause().args.args)
    local templates = ({
        A={'what are all %s?\t%s', 'are all %s %s?\tyes'},
        E={'what are all %s not?\t%s', 'is any %s %s?\tno'},
        I={'are some %s %s?\tyes'},
        O={'are all %s %s?\tno', 'are some %s not %s?\tyes'}
    })[form]
    return tablex.map(string.format, templates, term1, term2)
end

local Path = class('Path', 'Template')

function Path:__init(...)
    Template.__init(self, ...)
end

Path.clauses = 1

function Path:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'eval' then
        if is_property_clause(self:clause().args, 'path') then
            return true
        end
    end
end

function Path:render()
    local source = self:clause().args.args[1]
    local target, path = unpack(self:clause().args.args[3])
    local template = 'what is the path from %s to %s?\t%s'
    return {template:format(source, target, stringx.join(',', path))}
end

function Path:render_symbolic()
    local source = self:clause().args.args[1]
    local target, path = unpack(self:clause().args.args[3])
    local template = 'path %s %s\t%s'
    return {template:format(source, target, stringx.join(',', path))}
end

local IsIn = class('IsIn', 'Template')

function IsIn:__init(...)
    Template.__init(self, ...)
end

IsIn.clauses = 1

function IsIn:is_valid()
    if is_property_clause(self:clause(), 'is_in') then
        return true
    end
end

function IsIn:render()
    local entity, _, location = unpack(self:clause().args)
    local actor = {(entity.is_actor and '' or 'the ') .. '%s is '}
    local negation =
        self:clause().truth_value and {''} or {'not ', 'no longer '}
    local location_tmpl = {'in the %s'}
    return tablex.map(string.format,
                      combinations(actor, negation, location_tmpl),
                      entity.name, location.name)
end

local Is = class('Is', 'Template')

function Is:__init(...)
    Template.__init(self, ...)
end

Is.clauses = 1

function Is:is_valid()
    if is_property_clause(self:clause(), 'is') then
        return true
    end
end

function Is:render()
    local actor, _, object = unpack(self:clause().args)
    local template
    if object.is_adjective then
        template = '%s is %s'
    else
        template = '%s is a %s'
    end
    return {template:format(actor.name, object.name)}
end

local HasFear = class('HasFear', 'Template')

function HasFear:__init(...)
    Template.__init(self, ...)
end

HasFear.clauses = 1

function HasFear:is_valid()
    if is_property_clause(self:clause(), 'has_fear') then
        return true
    end
end

function HasFear:render()
    local animal, _, fears = unpack(self:clause().args)
    return {('%s are afraid of %s'):format(animal.plural, fears.plural)}
end

local HasColor = class('HasColor', 'Template')

function HasColor:__init(...)
    Template.__init(self, ...)
end

HasColor.clauses = 1

function HasColor:is_valid()
    if is_property_clause(self:clause(), 'has_color') then
        return true
    end
end

function HasColor:render()
    local animal, _, color = unpack(self:clause().args)
    return {('%s is %s'):format(animal.name, color.name)}
end

local HasCost = class('HasCost', 'Template')

function HasCost:__init(...)
    Template.__init(self, ...)
end

HasCost.clauses = 1

function HasCost:is_valid()
    if is_property_clause(self:clause(), 'has_cost') then
        return true
    end
end

function HasCost:render()
    local entity, _, cost = unpack(self:clause().args)
    local templates = {'a %s costs %s dollars',
                       'the price of a %s is %s dollars',
                       '%ss cost %s dollars each'}
    return tablex.map(string.format,
                      templates,
                      entity.name, cost)
end

local Owes = class('Owes', 'Template')

function Owes:__init(...)
    Template.__init(self, ...)
end

Owes.clauses = 1

function Owes:is_valid()
    if class.istype(self:clause(), 'Question') and
            is_property_clause(self:clause().args, 'owes') then
        return true
    end
end

function Owes:render()
    local actor, _, total = unpack(self:clause().args.args)
    local template = ('how much does %s need to pay?\t%s'):format(
        actor.name, NUMERALS[total]
    )
    return {template}
end

function Owes:render_symbolic()
    local actor, _, total = unpack(self:clause().args.args)
    local template = ('%s owes\t%s'):format( actor.name, total)
    return {template}
end

local CountHolding = class('CountHolding', 'Template')

function CountHolding:__init(...)
    Template.__init(self, ...)
end

CountHolding.clauses = 1

function CountHolding:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'count' and
            is_property_clause(self:clause().args, 'holding') then
        return true
    end
end

function CountHolding:render()
    local actor, _, objects = unpack(self:clause().args.args)
    local template = ('how many objects is %s holding?\t%s'):format(
        actor.name, NUMERALS[#objects]
    )
    return {template}
end

function CountHolding:render_symbolic()
    local actor, _, objects = unpack(self:clause().args.args)
    local template = ('%s hold\t%s'):format( actor.name, #objects)
    return {template}
end

local EvalHolding = class('EvalHolding', 'Template')

function EvalHolding:__init(...)
    Template.__init(self, ...)
end

EvalHolding.clauses = 1

function EvalHolding:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'eval' and
            is_property_clause(self:clause().args, 'holding') then
        return true
    end
end

function EvalHolding:render()
    local actor, _, objects = unpack(self:clause().args.args)
    local template = ('what is %s holding?\t'):format(actor.name)
    if #objects > 0 then
        template = template .. stringx.join(',', tablex.map(
            function(object) return object.name end, objects
        ))
    else
        template = template .. 'nothing'
    end
    return {template}
end

function EvalHolding:render_symbolic()
    local actor, _, objects = unpack(self:clause().args.args)
    local template = ('%s hold\t'):format(actor.name)
    if #objects > 0 then
        template = template .. stringx.join(',', tablex.map(
            function(object) return object.name end, objects
        ))
    else
        template = template .. 'nothing'
    end
    return {template}
end

local BeforeIsIn = class('BeforeIsIn', 'Template')

function BeforeIsIn:__init(...)
    Template.__init(self, ...)
end

BeforeIsIn.clauses = 1

function BeforeIsIn:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'before' and
            is_property_clause(self:clause().args[1], 'is_in') and
            is_property_clause(self:clause().args[2], 'is_in') and
            self:clause().args[1].args[1] == self:clause().args[2].args[1] then
        return true
    end
end

function BeforeIsIn:render()
    local template
    local clause1, clause2 = unpack(self:clause().args)
    if clause1.args[1].is_actor then
        template = 'where was %s before the %s?'
    else
        template = 'where was the %s before the %s?'
    end
    return {(template .. '\t%s'):format(clause1.args[1].name,
                                        clause2.args[3].name,
                                        clause1.args[3].name)}
end

function BeforeIsIn:render_symbolic()
    local template
    local clause1, clause2 = unpack(self:clause().args)
    return {('%s is_in %s\t%s'):format(clause1.args[1].name,
                                       clause2.args[3].name,
                                       clause1.args[3].name)}
end

local Both = class('Both', 'Template')

function Both:__init(...)
    Template.__init(self, ...)
end

Both.clauses = 1

function Both:is_valid()
    return self:clause().kind == 'both'
end

function Both:render()
    local template = 'who is in the %s and holding the %s?\t%s'
    template = template:format(self:clause().args[1].args[3],
                               self:clause().args[2].args[3],
                               self:clause().args[1].args[1])
    return {template}
end

local SimpleGive = class('SimpleGive', 'Simple')

function SimpleGive:__init(...)
    Template.__init(self, ...)
end

function SimpleGive:is_valid()
    if class.istype(self:clause().action, 'Give') then
        return true
    end
end

function SimpleGive:render()
    local actor = self:clause().actor
    local object, recipient = unpack(self:clause().args)
    local template = '%s gave %s the %s'
    return {template:format(actor.name, recipient.name, object.name)}
end

local EitherLocation = class('EitherLocation', 'Template')

function EitherLocation:__init(...)
    Template.__init(self, ...)
end

EitherLocation.clauses = 1

function EitherLocation:is_valid()
    if class.istype(self:clause(), 'EitherRule') then
        return true
    end
end

function EitherLocation:render()
    local locations = self:clause().locations
    return {('%s is either in the %s or in the %s'):format(
        self:clause().actor.name, locations[1].name, locations[2].name
    )}
end

local EvalGive = class('EvalGive', 'Template')

function EvalGive:__init(...)
    Template.__init(self, ...)
end

EvalGive.clauses = 1

function EvalGive:is_valid()
    return class.istype(self:clause(), 'Question') and
        class.istype(self:clause().args.action, 'Give')
end

function EvalGive:render()
    local actor = self:clause().args.actor
    local object, recipient = unpack(self:clause().args.args)
    local tmpl1 = ('what did %s give to %s?\t%s'):format(
        actor.name, recipient.name, object.name
    )
    local tmpl2 = ('who received the %s?\t%s'):format(
        object.name, recipient.name
    )
    local tmpl3 = ('who did %s give the %s to?\t%s'):format(
        actor.name, object.name, recipient.name
    )
    return {tmpl1, tmpl2, tmpl3}
end

function EvalGive:render_symbolic()
    local actor = self:clause().args.actor
    local object, recipient = unpack(self:clause().args.args)
    local tmpl1 = ('%s give_what %s\t%s'):format(
        actor.name, recipient.name, object.name
    )
    local tmpl2 = ('%s receive\t%s'):format(
        object.name, recipient.name
    )
    local tmpl3 = ('%s give %s\t%s'):format(
        actor.name, object.name, recipient.name
    )
    return {tmpl1, tmpl2, tmpl3}
end

function ConjunctionTeleport:__init(...)
    Template.__init(self, ...)
end

ConjunctionTeleport.clauses = 2

function ConjunctionTeleport:add_mentions()
    self.mentions[self.j] = List{self:clause().actor,
                                 self.story[self.i + 1].actor}
end

function ConjunctionTeleport:is_valid()
    local simple1, simple2 = self:clause(), self:clause(self.i + 1)
    if self.i < #self.story then
        local are_teleports = (class.istype(simple1.action, 'Teleport') and
                               class.istype(simple2.action, 'Teleport'))
        if are_teleports and
            simple1.actor ~= simple2.actor and
            simple1.args[1] == simple2.args[1] and
            math.random() < self.config['conjunction'] and
            not self:cast(CompoundCoreferenceTeleport):is_valid() then
            return true
        end
    end
end

function ConjunctionTeleport:render()
    local names = {self:clause().actor.name, self.story[self.i + 1].actor.name}
    local order = math.random(2)
    local conjunction = ('%s and %s'):format(names[order], names[3 - order])
    return self:cast(SimpleTeleport):render(conjunction)
end

local SimpleOrdering = class('SimpleOrdering', 'Template')

function SimpleOrdering:__init(...)
    Template.__init(self, ...)
end

SimpleOrdering.clauses = 1

function SimpleOrdering:is_valid()
    if is_property_clause(self:clause(), '>') then
        return true
    end
end

function SimpleOrdering:render()
    local template = 'the %s is bigger than the %s'
    return {template:format(self:clause().args[1], self:clause().args[3])}
end

local EvalOrdering = class('EvalOrdering', 'Template')

function EvalOrdering:__init(...)
    Template.__init(self, ...)
end

EvalOrdering.clauses = 1

function EvalOrdering:is_valid()
    if class.istype(self:clause(), 'Question') and
            self:clause().kind == 'eval' and
            is_property_clause(self:clause().args, '>') then
        return true
    end
end

function EvalOrdering:render()
    local x, y = self:clause().args.args[1], self:clause().args.args[3]
    local templates1 = {'is the %s bigger than %s?\tyes',
                        'does the %s fit in the %s?\tno'}
    local templates2 = {'is the %s bigger than %s?\tno',
                        'does the %s fit in the %s?\tyes'}
    templates1 = tablex.map(string.format, templates1, x, y)
    templates2 = tablex.map(string.format, templates2, y, x)
    return List(templates1):extend(templates2)
end

function EvalOrdering:render_symbolic()
    local x, y = self:clause().args.args[1], self:clause().args.args[3]
    local templates1 = {'is the %s bigger than %s?\tyes',
                        'does the %s fit in the %s?\tno'}
    local templates2 = {'is the %s bigger than %s?\tno',
                        'does the %s fit in the %s?\tyes'}
    templates1 = tablex.map(string.format, templates1, x, y)
    templates2 = tablex.map(string.format, templates2, y, x)
    return tablex.map(string.format, {'%s > %s\ttrue', '%s < %s\tfalse'}, x, y)
end

local templates =
    Set{BeforeIsIn, Both, ConjunctionTeleport, CoreferenceTeleport,
        CountHolding, Dir, EitherLocation, EvalDir, EvalGive, EvalHolding,
        EvalIsIn, IsIn, SimpleDrop, SimpleGet, SimpleGive, SimpleTeleport,
        YesNoIsIn, CompoundCoreferenceTeleport, CountGet, Owes, HasCost,
        BuyGet, Path, EvalBefore, Is, EvalHasFear, HasFear, HasColor,
        EvalHasColor, YesNoDir, SimpleOrdering, EvalOrdering, WhyTeleport,
        WhyGet, Motivation}

-- Text generation

local function add_line_numbers(lines)
    for i, line in ipairs(lines) do
        lines[i] = i .. ' ' .. line
    end
    return lines
end

local function capitalize(line)
    return line:gsub("^%l", string.upper)
end

local default_config = {
    coreference=0.0,
    conjunction=0.0,
    compound=0.0,
    directions='cardinal'
}

local function generate_symbolic_name(symbolic_names)
    local new_name = ''
    local i = #tablex.keys(symbolic_names) + 1
    for j = 1, math.ceil(i / 26) do
        new_name = new_name .. string.char(65 + ((i - 1) % 26))
    end
    return new_name
end

local function to_string(obj, symbolic_names)
    local t = class.type(obj)
    if t == 'string' then
        return obj:gsub(' ', '_')
    elseif t == 'nil' then
        return 'nothing'
    elseif t == 'number' then
        return tostring(obj)
    elseif t == 'table' then
        return ('%s'):format(List(obj))
    elseif t == 'Entity' then
        if obj.name == 'god' then
            return 'god'
        end
        return symbolic_names[obj]
    elseif class.istype(obj, 'Action') then
        return t:lower():gsub(' ', '_')
    else
        return tostring(t):gsub(' ', '_')
    end
end

local function stringify_symbolic(story, knowledge, config)
    local symbolic_names = {}
    local world
    local i = 1
    while not world do
        world = story[i].world
        i = i + 1
    end
    for id, entity in pairs(world.entities) do
        local symbolic_name = generate_symbolic_name(symbolic_names)
        symbolic_names[entity] = symbolic_name
        entity.name = entity.name == 'god' and 'god' or symbolic_name
    end
    local text = ''
    for i, clause in ipairs(story) do
        text = text .. i .. ' '
        if class.istype(clause, 'Question') then
            text = text .. clause.kind .. ' '
            local loaded_templates = Set.map(
                templates,
                function(template)
                    return template(i, i, story, knowledge, config, List(), {})
                end
            )
            local valid_templates = tablex.filter(
                Set.values(loaded_templates),
                function(template)
                    return template:is_valid()
                end
            )
            local options = valid_templates[1]:render_symbolic(symbolic_names)
            text = text .. options[math.random(#options)]
            text = text .. '\t'
            for _, support_clause in ipairs(tablex.keys(clause.support)) do
                text = text .. story:index(support_clause) .. ' '
            end
            text = text:sub(1, -2)
        elseif class.istype(clause, 'Rule') then
            -- TODO Symbolic rule here
            text = text .. 'rule'
        else
            local elements = {unpack(clause.args)}
            if not class.istype(clause.action, 'SetProperty') then
                table.insert(elements, 1, clause.action)
            end
            if clause.actor.name ~= 'god' then
                table.insert(elements, 1, clause.actor)
            end
            text = text .. stringx.join(' ', tablex.map(
                to_string, elements, symbolic_names
            ))
        end
        text = text .. '\n'
    end
    return text:sub(1, -2)
end

local function stringify(story, knowledge, config)
    config = tablex.merge(default_config, config or {}, true)
    if config.symbolic then
        return stringify_symbolic(story, knowledge, config)
    end
    local i = 1  -- The number of descriptions processed
    local j = 1  -- The number of lines output
    local clause_lines = {}  -- The line on which a clause was rendered
    local lines = List() -- List of rendered templates
    local mentions = List() -- A list of lists (mentions in each template)
    local coreferences = {} -- Mapping from clause to clause
    while true do
        -- Find the templates that are valid
        local loaded_templates = Set.map(
            templates,
            function(template)
                return template(i, j, story, knowledge, config,
                                mentions, coreferences)
            end
        )
        local valid_templates = tablex.filter(
            Set.values(loaded_templates),
            function(template)
                return template:is_valid()
            end
        )

        local template
        if #valid_templates == 0 then
            error('no valid template found')
        else
            template = utilities.choice(valid_templates)[1]
        end
        template:add_coreferences()
        template:add_mentions()
        local options = template:render()
        local line = options[math.random(#options)]

        if class.istype(story[i], 'Question') then
            -- Add supporting line numebrs
            line = line .. '\t'
            if not story[i].support then
                error('no support found')
            else
                local support_lines = List()
                for _, support in pairs(Set.values(story[i].support)) do
                    support_lines:append(clause_lines[support])
                    if coreferences[support] then
                        support_lines:append(
                            clause_lines[coreferences[support]]
                        )
                    end
                end
                local support = stringx.join(' ', support_lines)
                line = line .. support
            end
        else
            -- Add a period
            if not PUNCTUATION[line:sub(-1, -1)] then
                line = line .. '.'
            end
        end
        lines:append(line)

        -- Keep track of where clauses were rendered
        for k = i, i + template.clauses - 1 do
            clause_lines[story[k]] = j
        end

        -- Increment counters
        i = i + template.clauses
        j = j + 1
        if i > #story then
            break
        end
    end
    lines = tablex.map(capitalize, lines)
    lines = add_line_numbers(lines)
    return stringx.join('\n', lines)
end

return stringify
