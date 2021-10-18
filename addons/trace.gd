extends Spatial

"""
trace.gd

- Uses direct_space_state functions for 3D shape collision testing
- Various functions for specific collision tests
- Treated as an object to simplify getting collision info
"""

var endpos : Vector3
var fraction : float
var normal : Vector3
var type : String
var groups : PoolStringArray
var hit : bool

"""
===============
new
===============
"""
func new():
	endpos = Vector3.ZERO
	fraction = 0.0
	normal = Vector3.ZERO
	type = ""
	groups = PoolStringArray()
	hit = false
	
	return self

"""
===============
motion
===============
"""
func motion(origin : Vector3, dest : Vector3, shape : Shape, e):
	var params
	var space_state
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	space_state = get_world().direct_space_state
	var results = space_state.cast_motion(params, dest - origin)
	fraction = results[0]

"""
===============
rest
===============
"""
func rest(origin : Vector3, shape : Shape, e, mask):
	var params
	var space_state
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.set_collision_mask(mask)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	hit = false
	
	space_state = get_world().direct_space_state
	var results = space_state.get_rest_info(params)
	
	if results.empty():
		return
	
	hit = true
	normal = results.get("normal")

"""
================
intersect_groups
================
"""
func intersect_groups(origin : Vector3, shape : Shape, e, mask):
	var params : PhysicsShapeQueryParameters
	var space_state
	var results
	
	groups = PoolStringArray()
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	params.set_collision_mask(mask)
	
	hit = false
	
	space_state = get_world().direct_space_state
	results = space_state.intersect_shape(params, 8)
	
	if results.empty():
		return
	
	hit = true
	
	for r in results:
		var group = r.get("collider").get_groups()
		if len(group) > 0:
			groups.append(group)

"""
===============
standard
===============
"""
func standard(origin : Vector3, dest : Vector3, shape : Shape, e):
	var params : PhysicsShapeQueryParameters
	var space_state
	var results
	
	# Create collision parameters
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	#params.set_collision_mask(mask)
	
	hit = false
	
	# Get distance fraction and position of first collision
	space_state = get_world().direct_space_state
	results = space_state.cast_motion(params, dest - origin)
	
	if !results.empty():
		fraction = results[0]
		endpos = origin + (dest - origin).normalized() * (origin.distance_to(dest) * fraction)
	else:
		fraction = 1
		endpos = dest
		return # didn't hit anything
	
	hit = true
	
	# Set next parameter position to endpos
	params.transform.origin = endpos
	
	# Get collision normal
	results = space_state.get_rest_info(params)
	if !results.empty():
		normal = results.get("normal")
	else:
		normal = Vector3.UP

"""
===============
full
===============
"""
func full(origin : Vector3, dest : Vector3, shape : Shape, e):
	var params : PhysicsShapeQueryParameters
	var space_state
	var results
	var col_id
	
	# Create collision parameters
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	hit = false
	
	# Get distance fraction and position of first collision
	space_state = get_world().direct_space_state
	results = space_state.cast_motion(params, dest - origin)
	if !results.empty():
		fraction = results[0]
		endpos = origin + (dest - origin).normalized() * (origin.distance_to(dest) * fraction)
	else:
		fraction = 1
		endpos = dest
		return # Didn't hit anything
	
	hit = true
	
	# Set next parameter position to endpos
	params.transform.origin = endpos
	
	col_id = 0
	#type = "DEFAULT"
	
	# Get collision normal
	results = space_state.get_rest_info(params)
	if !results.empty():
		col_id = results.get("collider_id")
		normal = results.get("normal")
	else:
		normal = Vector3.UP
	
	# Get collision group
	if col_id != 0:
		results = space_state.intersect_shape(params, 8)
		if !results.empty():
			for r in results:
				if r.get("collider_id") == col_id:
					var g = r.get("collider").get_groups()
					if len(g) > 0:
						type = g[0]
					break


#"""
#===============
#group
#Returns collision groups and collider
#NOTE: Uses intersect_shape, so it passes through collision objects
#===============
#"""
#func group(origin : Vector3, shape, e, mask):
#	var params : PhysicsShapeQueryParameters
#	var space_state
#	var results
#	var groups = []
#	var colliders = []
#
#	params = PhysicsShapeQueryParameters.new()
#	params.set_shape(shape)
#	params.transform.origin = origin
#	params.collide_with_bodies = true
#	params.exclude = [e]
#	params.set_collision_mask(mask)
#
#	space_state = get_world().direct_space_state
#	results = space_state.intersect_shape(params, 8)
#
#	if !results.empty():
#		for r in results:
#			var group = r.get("collider").get_groups()
#			if len(group) > 0:
#				colliders.append(r.get("collider"))
#				groups.append(group)
#
#	return Array([groups, colliders])
