extends Spatial

"""
===============
motion
===============
"""
func motion(origin, dest, shape, e):
	var params
	var space_state
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	space_state = get_world().direct_space_state
	return space_state.cast_motion(params, dest - origin)

"""
===============
rest
===============
"""
func rest(origin : Vector3, shape, e, mask):
	var params
	var space_state
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.set_collision_mask(mask)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	space_state = get_world().direct_space_state
	return space_state.get_rest_info(params)

"""
================
intersect_groups
================
"""
func intersect_groups(origin : Vector3, shape, e, mask):
	var params : PhysicsShapeQueryParameters
	var space_state
	var results
	var groups = []
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	params.set_collision_mask(mask)
	
	space_state = get_world().direct_space_state
	results = space_state.intersect_shape(params, 8)
	
	if !results.empty():
		for r in results:
			var group = r.get("collider").get_groups()
			if len(group) > 0:
				groups.append(group)
		return groups
	
	return false

"""
===============
normal
===============
"""
func normal(origin, dest, shape, e):
	var endpos : Vector3 #[0]
	var normal : Vector3 #[1]
	
	# Create collision parameters
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	#params.set_collision_mask(mask)
	
	# Get distance fraction and position of first collision
	var space_state = get_world().direct_space_state
	var results = space_state.cast_motion(params, dest - origin)
	if !results.empty():
		var fraction = results[0]
		endpos = origin + (dest - origin).normalized() * (origin.distance_to(dest) * fraction)
	else:
		endpos = dest
		
		# Didn't hit anything
		return false
	
	# Set next parameter position to endpos
	params.transform.origin = endpos
	
	# Get collision normal
	results = space_state.get_rest_info(params)
	if !results.empty():
		normal = results.get("normal")
	else:
		normal = Vector3.UP
	
	return Array([endpos, normal])

"""
===============
normalfrac
===============
"""
func normalfrac(origin, dest, shape, e):
	var fraction : float #[0]
	var endpos : Vector3 #[1]
	var normal : Vector3 #[2]
	
	# Create collision parameters
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	# Get distance fraction and position of first collision
	var space_state = get_world().direct_space_state
	var results = space_state.cast_motion(params, dest - origin)
	if !results.empty():
		fraction = results[0]
		endpos = origin + (dest - origin).normalized() * (origin.distance_to(dest) * fraction)
	else:
		fraction = 1
		endpos = dest
	
	# Set next parameter position to endpos
	params.transform.origin = endpos
	
	# Get collision normal
	results = space_state.get_rest_info(params)
	if !results.empty():
		normal = results.get("normal")
	else:
		normal = Vector3.UP
	
	return Array([fraction, endpos, normal])

"""
===============
full
===============
"""
func full(origin, dest, shape, e):
	var fraction : float   #[0]
	var endpos   : Vector3 #[1]
	var normal   : Vector3 #[2]
	var type     : String  #[3]
	
	# Create collision parameters
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	# Get distance fraction and position of first collision
	var space_state = get_world().direct_space_state
	var results = space_state.cast_motion(params, dest - origin)
	if !results.empty():
		fraction = results[0]
		endpos = origin + (dest - origin).normalized() * (origin.distance_to(dest) * fraction)
	else:
		fraction = 1
		endpos = dest
	
	# Set next parameter position to endpos
	params.transform.origin = endpos
	
	var col_id = 0
	type = "DEFAULT"
	
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
					var groups = r.get("collider").get_groups()
					if len(groups) > 0:
						type = groups[0]
					break
	
	return Array([fraction, endpos, normal, type])


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
