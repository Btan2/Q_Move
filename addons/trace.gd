extends Spatial

"""
===============
fraction
Returns distance fraction
===============
"""
func fraction(origin, dest, shape, e):
	# Create collision parameters
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	# Get distance fraction
	var space_state = get_world().direct_space_state
	var results = space_state.cast_motion(params, dest - origin)
	if !results.empty():
		return results[0]
	else:
		return 1

"""
===============
group
Returns collision groups and collider
===============
"""
func group(origin : Vector3, shape, e):
	var params : PhysicsShapeQueryParameters
	var space_state
	var results
	var groups = []
	var colliders = []
	
	params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	space_state = get_world().direct_space_state
	results = space_state.intersect_shape(params, 8)
	
	if !results.empty():
		for r in results:
			var group = r.get("collider").get_groups()
			if len(group) > 0:
				colliders.append(r.get("collider"))
				groups.append(group)
	
	return Array([groups, colliders])

"""
===============
normal
Returns surface normal and end position
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
Returns distance fraction, surface normal and
end position
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
Returns distance fraction, end position, surface normal 
and collision group
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
					type = r.get("collider").get_groups()[0]
					break
	else:
		type = ""
	
	return Array([fraction, endpos, normal, type])
