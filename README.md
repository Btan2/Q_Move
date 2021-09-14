# Q_Move
A Quake-like controller for Godot.

# About
The aim of this project is to provide Godot devlopers with a robust character controller that delivers the same level of responsiveness as Quake and Half-Life. A majority of Quake-like controllers seem to lack the ability to handle steps and often have to resort to rudimentary workarounds such as invisible ramps or singular raycast lines which do not represent the player's hull accurately. This controller is an attempt to fix this issue and to recreate the idiosyncratic behaviours of the Quake and Half-Life controllers.

A generalised description on how the step function works can be found on my website: https://thelowrooms.xyz/articledir/collisionresponse_programming.php

NOTE: Website is currently under construction so it may contain broken links or text/heading alignment errors.

# Features
  - Various functions from Quake source code have been converted into GDScript, such as head-bob and camera movement rolling. 
  - Air control and acceleration was taken and modified from WiggleWizard's Quake3 Movement script (https://github.com/WiggleWizard/quake3-movement-unity3d).
  - Optional modern style head-bob converted from Admer456's "Better View Bobbing" tutorial (https://gamebanana.com/tuts/12972).
  - Proper step climbing; no invisible ramps or other trickery used.
  - Trace function addon for collision shape casting (used for step detection).
  - Jump hang to allow more forgiving jumping precision off ledges.
  - More standard FPS features to be added to the project over time.

# Current Issues
  - Trace function is a little inefficient as certain collision shape casting methods will not return all of the required information for collision response. Multiple casting methods are required in order to retrieve the distance fraction, collision normal and end position of the shape when it collides with something.
  - The controller will slowly slide down non-steep slopes. This issue is common with Godot.
  - Complex geometry hasn't been tested yet, only simple box shapes have been used so far.
  - The player can slowly move up steep slopes that they should otherwise slide down, although this was also prevalent in Half-Life and Quake so I might keep it in for prosterity. Moving along the base of steep slopes that connect with ground can cause small camera jitters.

# License
This project is under the GNU v3 license. I would highly appreciate a credit if you use this in your project(s).
