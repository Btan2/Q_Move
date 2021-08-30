# Q_Move
A Quake-like controller for Godot.

# About
The aim of this project is to provide Godot devlopers with a robust character controller that delivers the same level of responsiveness as Quake and Half-Life. A distinctive feature the character controller from those games had was the ability to detect and climb up steps, as well as slide the player's velocity off colliding surfaces while airborne. A majority of Quake-like controllers seem to lack the ability to handle steps and often have to resort to rudimentary workarounds such as invisible ramps or singular raycast lines which do not represent the player's hull accurately. They also do not seem to take the player's feet into account, resulting in the unrealistic ability to jump up starcases with nary an interruption. This controller is an attempt to fix these issues.

# Features
  - Various functions from Quake source code converted into GDScript
  - Proper step climbing; no invisible ramps or other inefficient trickery used
  - Trace function addon for collision shape detection
  - Air control and acceleration, modified from WiggleWizards Quake3 Movement script (https://github.com/WiggleWizard/quake3-movement-unity3d)
  - Jump hang to make jumping precision more lax or difficult
  - Classic head-bob and view-rolling functions from Quake source code
  - Optional modern head-bob from Admer456's "Better View Bobbing" tutorial (https://gamebanana.com/tuts/12972)
  - Weapon-bob and roll
  - Weapon look sway in a similar vein to Half-Life 2
  - Idle weapon and view sway

# Current Issues
  - Trace function is a little inefficient as certain collision shape casting methods will not return all of the required information for collision response. I have to use 3 different collision shape casts in order to retrieve the distance fraction, collision normal and position of the shape when it collides with something. This is undesirable, so hint-hint Godot engine developers...
  - The controller will slowly slide down slopes, although this is an issue across the board with Godot.
  - Complex geometry hasn't been tested yet, only simple box shapes have been used so far.
  - Slight collision jitters when moving against two object surfaces that overlap one another.

# License
This project is under the GNU v3 license. I would highly appreciate a credit if you use this in your project(s).
