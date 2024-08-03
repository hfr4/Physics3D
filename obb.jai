My_OBB :: struct {
    position:  Vector3;
    rotation:  Vector3;
    half_size: Vector3;

    right:     Vector3;
    up:        Vector3;
    forward:   Vector3;

    vertices:  [8] Vector3;

    aabb: struct { 
        min: Vector3; 
        max: Vector3; 
    };
}

update :: (using obb: *My_OBB) {
    cx := cos(rotation.x);
    cy := cos(rotation.y);
    cz := cos(rotation.z);
    
    sx := sin(rotation.x);
    sy := sin(rotation.y);
    sz := sin(rotation.z);

    // XYZ

    right = .{
         cy * cz,
         sx * sy * cz + cx * sz,
        -cx * sy * cz + sx * sz
    };

    up = .{
        -cy * sz,
        -sx * sy * sz + cx * cz,
         cx * sy * sz + sx * cz
    };
    
    forward = .{
         sy,
        -sx * cy,
         cx * cy
    };

    for i: 0..7 {
        x := ifx i       % 4 < 2 then -half_size.x else  half_size.x;
        y := ifx (i + 1) % 4 < 2 then  half_size.y else -half_size.y;
        z := ifx i           < 4 then -half_size.z else  half_size.z;

        pos := Vector3.{
            position.x + x * right.x + y * up.x + z * forward.x,
            position.y + x * right.y + y * up.y + z * forward.y,
            position.z + x * right.z + y * up.z + z * forward.z,
        };

        vertices[i] = position;
    }
}


intersects :: (A: My_OBB, B: My_OBB) -> float, Vector3, bool {
        min_depth := FLOAT32_MAX;;
        direction: Vector3;

        axes := Vector3.[ 
            A.right, A.up, A.forward, 
            B.right, B.up, B.forward,
            cross_and_normalize(A.right  , B.right  ),
            cross_and_normalize(A.right  , B.up     ),
            cross_and_normalize(A.right  , B.forward),
            cross_and_normalize(A.up     , B.right  ),
            cross_and_normalize(A.up     , B.up     ),
            cross_and_normalize(A.up     , B.forward),
            cross_and_normalize(A.forward, B.right  ),
            cross_and_normalize(A.forward, B.up     ),
            cross_and_normalize(A.forward, B.forward),
        ];

        for axis: axes {
            if axis.x == 0 && axis.y == 0 && axis.z == 0 continue;
            
            a_min :=  FLOAT32_MAX;
            a_max := -FLOAT32_MAX;

            b_min :=  FLOAT32_MAX;
            b_max := -FLOAT32_MAX;

            projection: float;
    
            for i: 0..7 {
                projection = dot(A.vertices[i], axis);

                if projection < a_min a_min = projection;
                if projection > a_max a_max = projection;

                projection = dot(B.vertices[i], axis);

                if projection < b_min b_min = projection;
                if projection > b_max b_max = projection;
            }

            // check for cases when the projection is fully inside the projection of the other object
            depth := ifx a_max > b_max && a_min < b_min then min(a_max - b_min, b_max - a_min)
                else ifx b_max > a_max && b_min < a_min then min(b_max - a_min, a_max - b_min)
                else                                         min(a_max, b_max) - max(a_min, b_min);

            if depth > 0.0 {
                if depth < min_depth {
                    min_depth = depth;
                    direction = axis;
                }
            } else {
                return min_depth, direction, false;
            }

        }

        amount := direction.x * (A.position.x - B.position.x) + 
                  direction.y * (A.position.y - B.position.y) + 
                  direction.z * (A.position.z - B.position.z);

        if amount < 0.0 {
            direction.x *= -1;
            direction.y *= -1;
            direction.z *= -1;
        }

        return min_depth, direction, true;
}

cross_and_normalize :: (a: Vector3, b: Vector3) -> Vector3 {
	result := Vector3.{
		a.y * b.z - a.z * b.y,
		a.z * b.x - a.x * b.z,
		a.x * b.y - a.y * b.x,
	};

	len := length(result);

	if len != 0.0 {
		result.x /= len;
		result.y /= len;
		result.z /= len;
	}

	return result;
}