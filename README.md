# Q_Move
A Quake-like controller for Godot.

# Current Engine Version: Godot 3.3.4
NB: The next update will be adjusted to work in Godot 3.5. Additional features (pmove_full, ladder climbing and etc.) will be temporarily removed and reintroduced at a later date.
<br>
<i>The aim is to update the project along with each stable release until Godot 4 is released.</i>

# About
The aim of this project is to provide Godot developers with a robust character controller that delivers the same level of responsiveness as Quake and Half-Life. A majority of Quake-like controllers seem to lack the ability to handle steps and often have to resort to rudimentary workarounds such as invisible ramps or singular raycast lines which do not represent the player's hull accurately. This controller is an attempt to fix this issue and to recreate the idiosyncratic behaviours of the Quake and Half-Life controllers.

A generalised description on how the step function works can be found on my website: https://thelowrooms.com/articledir/programming_stepclimbing.php

# Features
  - Various functions from Quake source code have been converted into GDScript, such as head-bob and camera movement rolling. 
  - Air control and acceleration was taken and modified from WiggleWizard's Quake3 Movement script (https://github.com/WiggleWizard/quake3-movement-unity3d).
  - Optional modern style head-bob converted from Admer456's "Better View Bobbing" tutorial (https://gamebanana.com/tuts/12972).
  - Proper step climbing; no invisible ramps or other trickery used.
  - Trace singleton addon for collision shape casting (used for step detection).
  - Jump hang to allow more forgiving jumping precision off ledges.
  - More standard FPS features to be added to the project over time.

# Current Issues
  - Sliding along a wall while moving into a step can sometimes stop the player or just come off as buggy.<b> -> [working on it] </b>
  - The trace functions are a little inefficient as multiple casting methods are required to retrieve collision information; a standard trace call will cast 3 shape queries for collision info.
  - The controller will slowly slide down non-steep slopes. This issue is common with Godot.
  - Complex geometry hasn't been tested yet, only simple box shapes have been used so far.
  - The player can fall infinitely if caught between two steep slopes.<b> -> [working on it] </b>
  - The player can sometimes move up if pressed between two steep slopes when they should otherwise slide down, although this was also prevalent in Half-Life and Quake so I might keep it in for prosterity.

# License
This project is under the GNU v3 license. I would highly appreciate a credit if you use this in your project(s).
