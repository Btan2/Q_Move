# Q_Move
A Quake-like controller for Godot.
<br>
<br>**Github Version:** Godot 3.5
<br>**Updated Version:** Godot 4.2.1 Mono
<br>
<br>
<img src="https://github.com/Btan2/Q_Move/assets/17605586/6001394d-276a-442a-90ad-d20b3d69cf2e"></img>
<br>
<sub>Testing E1M2 (without the roof)</sub>
<br>
<br>

The aim of this project is to provide Godot developers with a robust character controller that delivers a similar level of responsiveness as Quake and Half-Life.
The complete controller will be able to climb ladders, jump, crouch and swim and climb steps and low geometry.
<br>
<br>**Features:**
  * Using Quake and Quake 3 source code to calculate player movement physics.
  * Smoother collisions with level geometry.
  * Versatile step detection and climbing.
  * Works with imported Mesh geometry.
<br>
<img src="https://github.com/Btan2/Q_Move/assets/17605586/67360fdc-5039-4081-af13-5e0b11646fae"></img>
<br>
<br>

[ **Upcoming Update** ]
<br>
<br>
Please be aware that the next update will not be game-ready. The next update solely focused on re-writing player vs static geometry collision. Additional collision functions, like colliding with moving objects or raycasting, have not been programmed yet.
<br>
<br>
***The next update uses C# scripting, so only Mono engine builds will work***
<br>
<br>

# Scope:
The scope of this project will evolve over time as more features are implemented and completed.
  * Small, single player projects.
  * Low/medium poly level geometry.
  * Big open world games are not recommended.
<br>

# Credits:
  * Air control is copied and modified from WiggleWizard's Quake3 Movement script <br> https://github.com/WiggleWizard/quake3-movement-unity3d
  * Modern style head-bob converted from Admer456's "Better View Bobbing" tutorial <br> https://gamebanana.com/tuts/12972
  * A generalised description on how a step climbing function works can be found on my website <br> https://thelowrooms.com/articledir/programming_stepclimbing.php
<br>

# TODO:
  [ **Upcoming Update** ]
  * Proper multi plane velocity clipping.
  * Proper sphere casting.  
  * Moving objects: boxes, spheres, lifts.
  * Scene partitioning
  * Crouching
  * Ladders
  * Swimming
  * Raycasting
  * Nav-mesh implementation  
<br>

# Issues:
  [ **Upcoming Update** ]
  * Player vs static objects only.
  * Mono builds only
  * Dense, high poly mesh objects should be avoided.
  * Some sharp angles will cause jittering.
  * Does not interact with the Godot physics engine.
  * The player can fall infinitely if caught between multiple steep slopes with no stable ground beneath, which is the correct behaviour. This can be circumvented by adding invisible geometry to block access to bad spots.
  * Similar to Half-Life and Quake, the player can slowly creep up and along the sharp crevice of two steep surfaces.
<br>

# License
This project is under the GNU v3 license. I would highly appreciate a credit if you use this in your project(s).
