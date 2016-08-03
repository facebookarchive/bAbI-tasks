bAbI tasks
==========

This repository contains code to generate the `bAbI tasks`__ as described in the paper
`Towards AI-Complete Question Answering: A Set of Prerequisite Toy Tasks`__.
Please cite the paper if you use this code in your work (bibtex entry `here`__).

__ http://fb.ai/babi
__ http://arxiv.org/abs/1502.05698
__ http://dblp.uni-trier.de/rec/bibtex/journals/corr/WestonBCM15

.. contents:: :depth: 2

Installation
------------

This project requires Torch to be installed. The easiest way to install Torch
is by following the installation instructions at `torch/distro`__.  To use the
library, install it with LuaRocks by running the following command from the
root directory.

.. code:: bash

   luarocks make babitasks-scm-1.rockspec

__ https://github.com/torch/distro

Usage
-----

To generate a task, run the command

.. code:: bash

    babi-tasks <task-id>

where ``<task-id>`` is either a class name (like ``PathFinding``) or the task
number (e.g. 19). To quickly generate 1000 examples of each task, you can use

.. code:: bash

    for i in `seq 1 20`; do babi-tasks $i 1000 > task_$i.txt; done

Tasks
-----

The tasks in ``babi/tasks`` correspond to those from the original dataset as
follows:

== ============================================= ===================
#   Task                                         Class name
== ============================================= ===================
 1  Basic factoid QA with single supporting fact WhereIsActor
 2  Factoid QA with two supporting facts         WhereIsObject
 3  Factoid QA with three supporting facts       WhereWasObject
 4  Two argument relations: subject vs. object   IsDir
 5  Three argument relations                     WhoWhatGave
 6  Yes/No questions                             IsActorThere
 7  Counting                                     Counting
 8  Lists/Sets                                   Listing
 9  Simple Negation                              Negation
10  Indefinite Knowledge                         Indefinite
11  Basic coreference                            BasicCoreference
12  Conjunction                                  Conjunction
13  Compound coreference                         CompoundCoreference
14  Time manipulation                            Time
15  Basic deduction                              Deduction
16  Basic induction                              Induction
17  Positional reasoning                         PositionalReasoning
18  Reasoning about size                         Size
19  Path finding                                 PathFinding
20  Reasoning about agent's motivation           Motivations
== ============================================= ===================

    Note: This code is a rewrite of the original code that was used to
    generate the publicly available dataset at `fb.ai/babi`__. As such, it
    is not possible to produce exactly the same dataset.
    However, we have verified that numbers obtained are very similar.

__ http://fb.ai/babi

Task flags
~~~~~~~~~~
Some tasks accept configuration flags that will change their output.

In both the ``PathFinding`` and ``Size`` the number of inference steps required
to answer the question can be changed. You can also control the number of
"decoys" (locations that are not part of the path).

.. code:: bash

   babi-tasks PathFinding --path-length 3 --decoys 1
   babi-tasks Size --steps 3

Currently the path length plus the number of decoys has to be 5 or less.
Similarly, the number of size comparisons cannot be more than 5.

For tasks involving people moving around, the use of coreferences and
conjunctions can be controlled with the flags ``--coreference`` and
``--conjunction``. These flags take a number between 0 and 1 as an argument,
determining the fraction of the time coreferences and conjunctions are used
respectively.

.. code:: bash

   babi-tasks WhereIsActor --coreference 1.0

Tasks can also be rendered in a more symbolic manner. Use the flag ``--symbolic
true`` to enable this.::

  1 H teleport N
  2 H teleport F
  3 eval H is_in  F       2

Code Overview
-------------

Tasks are generated through simulation: We have a world containing entities_,
and actions_ that can add new entities to the world, or modify entities' states.
Simulations then just take the form of sampling actions that are valid.

We often want to ask questions that require some sort of logical inference. Some
types of inference can be re-used in multiple tasks, for example the deduction
that a person and the object they are holding are in the same place is used
several times. For this reason, some of the reasoning has been factored out: We
keep track of what the reader of a story knows about the world, and each time a
new line is read, we update this knowledge_.

What follows is a brief overview of the classes and concepts used, which should
help guide the understanding of the code.

World
~~~~~

A world is a collection of entities. Worlds can be loaded from text files such
as those found in ``babi/tasks/worlds`` using the ``world:load(filename)``
command.

.. _entities:

Entity
~~~~~~

All concepts and objects in the simulations are entities. They are effectively
Lua tables that describe the entity's properties.

Actions
~~~~~~~

Actions modify the state of the world. Each action is performed by an entity,
even actions like setting the location or size of another entity (these are
usually performed by the entity "god").

An action's ``is_valid`` method will test whether an action can be performed
e.g. John cannot move to the kitchen if he is already there. The ``perform``
method assumes that the action is valid, and modifies the world accordingly
i.e. it will change the location of John.

Lastly, actions can update the reader's knowledge_ of the world. For example,
if we know that John is in the kitchen, the action "John grabs the milk"
informs the reader that the milk is in the kitchen as well.

Knowledge
~~~~~~~~~

The ``Knowledge`` class keeps track of what a reader currently knows about the
world. When actions_ are performed, the ``Action.update_knowledge`` method can
update this knowledge accordingly. For example, when ``Knowledge`` contains
the information that John is in the kitchen, the action of dropping the milk
will result in the knowledge being updated to say that the milk is in the
kitchen, and that it isn't being held by anyone.

The ``Knowledge`` class takes into account some basic logical rules. For
example, some properties are "exclusive" in the sense that only one value can be
true (John cannot be in the kitchen and the garden at the same time, but he can
be not in the kitchen and not in the garden at the same time). Reversely, this
means that if John is in the garden, the reader knows that he is not in the
kitchen.

We keep track of which actions gave us which pieces of information about the
world. This way, we can provide the user with the supporting facts when asking
questions.

.. _clauses:

Clause
~~~~~~

Facts about the world are expressed as clauses of the form ``(truth value,
actor, action, arguments)``. For example ``(true, john, teleport, kitchen)``
means that John moved to the kitchen, while ``(false, john, drop, milk)``
means that John did *not* drop the milk. Note that because all information
must be conveyed as actions, the sentence "John is in the garden" is
represented as ``(true, god, set_property, is_in, garden)``.

.. _questions:

Question
~~~~~~~~

A question is represented as a tuple of the form ``(question type, clause,
support)``.

    | 1 John is in the garden.
    | 2 Where is John?  garden  1

This story is represented as a clause, ``clause = (true, god, set_property,
john, is_in, garden)``, followed by a question, ``question = (evaluate, clause,
{1})``. A question like "Is john in the garden?" would instead be represented as
``question = (yes_no, clause, {1})``.

Natural language generation
~~~~~~~~~~~~~~~~~~~~~~~~~~~

After the simulation is complete, a story (task) is nothing more but a list of
clauses_ and questions_. We turn this into text using the ``stringify``
function. This function performs a simple process: It repeatedly tries to find
templates that can turn the next clause(s) or question(s) into text. It randomly
samples a template from the matching ones, and goes on to the next clause that
needs to be converted.

Templates can be selected further based on configuration (each task has a
default configuration, but they can be passed through the command line as
well). This enables turning on things like coreferences, conjunctions, etc.

References
----------

* Jason Weston, Antoine Bordes, Sumit Chopra, Tomas Mikolov, Alexander M. 
  Rush, Bart van Merriënboer, "`Towards AI-Complete Question Answering: A Set of Prerequisite Toy
  Tasks`__", *arXiv:1502.05698 [cs.AI]*.
* Sainbayar Sukhbaatar, Arthur Szlam, Jason Weston, Rob Fergus, "`End-To-End
  Memory Networks`__", *arXiv:1503.08895 [cs.NE]*.

__ http://arxiv.org/abs/1502.05698
__ http://arxiv.org/abs/1503.08895
