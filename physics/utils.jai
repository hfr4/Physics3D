AABB :: struct {
    min: Vector3;
    max: Vector3;
}

OBB :: struct {
    position:  Vector3;
    rotation:  Matrix3;
    half_size: Vector3;
}

Plane :: struct {
    position: Vector3;
    normal:   Vector3;
}

Segment :: struct {
    a, b: Vector3;
}

expand :: (using aabb: *AABB, p: Vector3) {
    if p.x < min.x  min.x = p.x;
    if p.y < min.y  min.y = p.y;
    if p.z < min.z  min.z = p.z;
    if p.x > max.x  max.x = p.x;
    if p.y > max.y  max.y = p.y;
    if p.z > max.z  max.z = p.z;
}

expand :: (using aabb: *AABB, pts: [] Vector3) {
    for pts  expand(aabb, it);
}

expand :: (using a: *AABB, b: AABB) {
    expand(a, b.min);
    expand(a, b.max);
}

collision_aabb_aabb :: (a: AABB, b: AABB) -> bool {
    if a.max.x < b.min.x || a.max.y < b.min.y || a.max.z < b.min.z return false;
    if b.max.x < a.min.x || b.max.y < a.min.y || b.max.z < a.min.z return false;
    return true;
}

aabb_contains_aabb :: (a: AABB, b: AABB) -> bool {
    return (
        b.min.x  >= a.min.x  && b.max.x < a.max.x &&
        b.min.y  >= a.min.y  && b.max.y < a.max.y &&
        b.min.z  >= a.min.z  && b.max.z < a.max.z
    );
}

aabbs_aabb :: (a: AABB, b: AABB) -> AABB {
    aabb_min := Vector3.{ min(a.min.x, b.min.x),  min(a.min.y, b.min.y),  min(a.min.z, b.min.z) };
    aabb_max := Vector3.{ max(a.max.x, b.max.x),  max(a.max.y, b.max.y),  max(a.max.z, b.max.z) };

    return .{ aabb_min, aabb_max };
}

fatt_aabb :: (a: AABB, margin: float) -> AABB {
    m := Vector3.{ margin, margin, margin };
    return .{ a.min - m, a.max + m };
}

collision_sphere_sphere :: (pa: Vector3, ra: float, pb: Vector3, rb: float) -> bool {
    r := ra + rb;
    return length_squared(pa - pb) <= r * r;
}

collision_point_obb :: (point: Vector3, obb: OBB) -> bool {
    dir := point - obb.position;

    for 0..2 {
        axis     := obb.rotation.v[it];
        distance := dot(dir, axis);

        if distance >  obb.half_size.component[it] return false;
        if distance < -obb.half_size.component[it] return false;
    }

    return true;
}

Interval :: struct {
    min: float;
    max: float;
}

get_interval :: (using obb: OBB, axis: Vector3) -> Interval {
    vertex: [8] Vector3; 

    q := ToQuaternion(rotation);

    CORNERS :: Vector3.[
        .{ -1, -1, -1 },
        .{  1, -1, -1 },
        .{ -1,  1, -1 },
        .{  1,  1, -1 },
        .{ -1, -1,  1 },
        .{  1, -1,  1 },
        .{ -1,  1,  1 },
        .{  1,  1,  1 },
    ];

    for CORNERS {
        vertex[it_index] = it * half_size;
        rotate(*vertex[it_index], q);
        vertex[it_index] += position;
    }

    result := Interval.{ FLOAT32_MAX, FLOAT32_MIN };

    for 0..7 {
        projection := dot(axis, vertex[it]);
        result.min = ifx projection < result.min then projection else result.min;
        result.max = ifx projection > result.max then projection else result.max;
    }

    return result;
}

overlap_on_axis :: (obb1: OBB, obb2: OBB, axis: Vector3) -> bool {
    a := get_interval(obb1, axis);
    b := get_interval(obb2, axis);
    return (b.min <= a.max) && (a.min <= b.max);
}

collision_obb_obb :: (a: OBB, b: OBB) -> bool {
    axis: [15] Vector3;
    axis[0] = a.rotation.v[0];
    axis[1] = a.rotation.v[1];
    axis[2] = a.rotation.v[2];
    axis[3] = b.rotation.v[0];
    axis[4] = b.rotation.v[1];
    axis[5] = b.rotation.v[2];

    for 0..2 { // Fill out rest of axis
        axis[6 + it * 3 + 0] = cross(axis[it], axis[0]);
        axis[6 + it * 3 + 1] = cross(axis[it], axis[1]);
        axis[6 + it * 3 + 2] = cross(axis[it], axis[2]);
    }

    for axis  {
        if !overlap_on_axis(a, b, it) {
            return false; // Seperating axis found
        }
    }

    return true; // Seperating axis not found
}

collision_obb_plane :: (a: OBB, b: Plane) -> bool {
	// Project the half extents of the AABB onto the plane normal
	pLen := a.half_size.x * abs(dot(b.normal, a.rotation.v[0])) +
            a.half_size.y * abs(dot(b.normal, a.rotation.v[1])) +
            a.half_size.z * abs(dot(b.normal, a.rotation.v[2]));
	// Find the distance from the center of the OBB to the plane
	dist := length(a.position - b.position);
	// Intersection occurs if the distance falls within the projected side
	return dist <= pLen;
}

closest_point :: (point: Vector3, plane: Plane) -> Vector3 {
	perpendicular_dist := dot(point - plane.position, plane.normal);
	closest            := point - perpendicular_dist * plane.normal;
	return closest;
}

collision_sphere_obb :: (a: Vector3, r: float, obb: OBB) -> bool {
    return distance(a, closest_point_on_obb(obb, a)) <= r;
}

closest_point_on_obb :: (obb: OBB, point: Vector3) -> Vector3 {
    result := obb.position;
    dir    := point - obb.position;

    for 0..2 {
        axis     := obb.rotation.v[it];
        distance := dot(dir, axis);

        if distance >  obb.half_size.component[it]  distance =  obb.half_size.component[it];
        if distance < -obb.half_size.component[it]  distance = -obb.half_size.component[it];

        result = result + (axis * distance);
    }

    return result;
}

ToMat3 :: (using q: Quaternion) -> Matrix3 {
    result := Matrix3_Identity;
    rotate(*result.v[0], q);
    rotate(*result.v[1], q);
    rotate(*result.v[2], q);

    return result;
}

ToQuaternion :: (using m: Matrix3) -> Quaternion {
    return get_rotation(m);
}

ToEuler :: (q: Quaternion) -> Vector3 {
    yaw, pitch, roll: float;

	siny_cosp :=     2 * (q.w * q.z + q.x * q.y);
	cosy_cosp := 1 - 2 * (q.y * q.y + q.z * q.z);
	yaw = atan2(siny_cosp, cosy_cosp);

	sinp := 2 * (q.w * q.y - q.z * q.x);
	if abs(sinp) >= 1 {
		// use 90 degrees if out of range
		pitch = ifx sinp < 0 then -PI/2 else PI/2; 
    } else {
		pitch = asin(sinp);
    }

	sinr_cosp :=     2 * (q.w * q.x + q.y * q.z);
	cosr_cosp := 1 - 2 * (q.x * q.x + q.y * q.y);
	roll = atan2(sinr_cosp, cosr_cosp);

	return .{ yaw, pitch, roll }; // z-axis, y-axis, x-axis 
}

FromEuler :: (yaw: float, pitch: float, roll: float) -> Quaternion { // z-axis, y-axis, x-axis 
	cos_y := cos(yaw   * 0.5);
	sin_y := sin(yaw   * 0.5);
	cos_p := cos(pitch * 0.5);
	sin_p := sin(pitch * 0.5);
	cos_r := cos(roll  * 0.5);
	sin_r := sin(roll  * 0.5);

	qx := sin_r * cos_p * cos_y - cos_r * sin_p * sin_y;
	qy := cos_r * sin_p * cos_y + sin_r * cos_p * sin_y;
	qz := cos_r * cos_p * sin_y - sin_r * sin_p * cos_y;
	qw := cos_r * cos_p * cos_y + sin_r * sin_p * sin_y;

	return .{ qx, qy, qz, qw };
}

Inverse :: (using q: Quaternion) -> Quaternion {
    result := q;
    result *= 1.0 / length(result);
    result.x = -result.x;
    result.y = -result.y;
    result.z = -result.z;

    return result;
}

Vec2Cross :: (a: Vector2, b: Vector2) -> float {
    return a.x * b.y - b.x * a.y;
}

CompareSigns :: (a: float, b: float) -> bool {
    if a > 0.0 && b > 0.0 return true;
    if a < 0.0 && b < 0.0 return true;
    return false;
}

Cofactor :: (m: Matrix4, i: int, j: int) -> float {
    row1 := Vector3.{ m.coef[(i + 1) % 4][(j + 1) % 4], m.coef[(i + 1) % 4][(j + 2) % 4], m.coef[(i + 1) % 4][(j + 3) % 4] };
    row2 := Vector3.{ m.coef[(i + 2) % 4][(j + 1) % 4], m.coef[(i + 2) % 4][(j + 2) % 4], m.coef[(i + 2) % 4][(j + 3) % 4] };
    row3 := Vector3.{ m.coef[(i + 3) % 4][(j + 1) % 4], m.coef[(i + 3) % 4][(j + 2) % 4], m.coef[(i + 3) % 4][(j + 3) % 4] };
    det  := dot(row1, cross(row2, row3));
    sign := ifx ((i + j) % 2 == 0) then 1 else -1;

    return det * sign;
}

GetOrtho :: (vec: Vector3) -> Vector3, Vector3 {
    n := normalize(vec);
    w := ifx (n.z * n.z > 0.9 * 0.9) then Vector3.{ 1, 0, 0 } else Vector3.{ 0, 0, 1 };
    u := normalize(cross(w, n));
    v := normalize(cross(n, u));
    u = normalize(cross(v, n));

    return u, v;
}