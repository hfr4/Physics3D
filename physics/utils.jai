AABB :: struct {
    min: Vector3;
    max: Vector3;
}

OBB :: struct {
    position: Vector3;
    rotation: Matrix3;
    extents:  Vector3;
}

Plane :: struct {
    position: Vector3;
    normal:   Vector3;
}

Segment :: struct {
    a, b: Vector3;
}

Quad :: struct {
    a, b, c, d: Vector3;
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

        if distance >  obb.extents.component[it] return false;
        if distance < -obb.extents.component[it] return false;
    }

    return true;
}

get_vertices :: (using obb: OBB) -> [8] Vector3 {
    result: [8] Vector3;

    axes := get_axes(obb);

    result[0] = position - axes[0] * extents.x - axes[1] * extents.y + axes[2] * extents.z;
    result[1] = position + axes[0] * extents.x - axes[1] * extents.y + axes[2] * extents.z;
    result[2] = position + axes[0] * extents.x + axes[1] * extents.y + axes[2] * extents.z;
    result[3] = position - axes[0] * extents.x + axes[1] * extents.y + axes[2] * extents.z;
    result[4] = position - axes[0] * extents.x - axes[1] * extents.y - axes[2] * extents.z;
    result[5] = position + axes[0] * extents.x - axes[1] * extents.y - axes[2] * extents.z;
    result[6] = position + axes[0] * extents.x + axes[1] * extents.y - axes[2] * extents.z;
    result[7] = position - axes[0] * extents.x + axes[1] * extents.y - axes[2] * extents.z;

    return result;
}

get_edges :: (obb: OBB) -> [12] Segment {
    result: [12] Segment;

    vertices := get_vertices(obb);

    result[0]  = .{ vertices[0], vertices[1] };
    result[1]  = .{ vertices[1], vertices[2] };
    result[2]  = .{ vertices[2], vertices[3] };
    result[3]  = .{ vertices[3], vertices[0] };
    result[4]  = .{ vertices[4], vertices[5] };
    result[5]  = .{ vertices[5], vertices[6] };
    result[6]  = .{ vertices[6], vertices[7] };
    result[7]  = .{ vertices[7], vertices[4] };
    result[8]  = .{ vertices[0], vertices[4] };
    result[9]  = .{ vertices[1], vertices[5] };
    result[10] = .{ vertices[2], vertices[6] };
    result[11] = .{ vertices[3], vertices[7] };

    return result;
}

get_planes :: (using obb: OBB) -> [6] Plane {
    result: [6] Plane;

    axes := get_axes(obb);

    result[0] = .{ position + axes[0] * extents.x,  axes[0] };
    result[1] = .{ position - axes[0] * extents.x, -axes[0] };
    result[2] = .{ position + axes[1] * extents.y,  axes[1] };
    result[3] = .{ position - axes[1] * extents.y, -axes[1] };
    result[4] = .{ position + axes[2] * extents.z,  axes[2] };
    result[5] = .{ position - axes[2] * extents.z, -axes[2] };

    return result;
}

get_quads :: (using obb: OBB) -> [6] Quad {
    result: [6] Quad;

    vertices := get_vertices(obb);

    result[0] = .{ vertices[0], vertices[1], vertices[2], vertices[3] };
    result[1] = .{ vertices[4], vertices[7], vertices[6], vertices[5] };
    result[2] = .{ vertices[0], vertices[3], vertices[7], vertices[4] };
    result[3] = .{ vertices[1], vertices[5], vertices[6], vertices[2] };
    result[4] = .{ vertices[0], vertices[4], vertices[5], vertices[1] };
    result[5] = .{ vertices[3], vertices[2], vertices[6], vertices[7] };

    return result;
}

get_axes :: (using obb: OBB) -> [3] Vector3 {
    return rotation.v;
}

get_sat_axes :: (a: OBB, b: OBB) -> [15] Vector3 {
    a_axes := get_axes(a);
    b_axes := get_axes(b);

    result: [15] Vector3;
    result[0]  = a_axes[0];
    result[1]  = a_axes[1];
    result[2]  = a_axes[2];
    result[3]  = b_axes[0];
    result[4]  = b_axes[1];
    result[5]  = b_axes[2];
    result[6]  = normalize(cross(result[0], result[3]));
    result[7]  = normalize(cross(result[0], result[4]));
    result[8]  = normalize(cross(result[0], result[5]));
    result[9]  = normalize(cross(result[1], result[3]));
    result[10] = normalize(cross(result[1], result[4]));
    result[11] = normalize(cross(result[1], result[5]));
    result[12] = normalize(cross(result[2], result[3]));
    result[13] = normalize(cross(result[2], result[4]));
    result[14] = normalize(cross(result[2], result[5]));

    return result;
}

get_projected_interval :: (using obb: OBB, axis: Vector3) -> float, float {
    vertices := get_vertices(obb);

    min :=  FLOAT32_MAX; 
    max := -FLOAT32_MAX;

    for vertices {
        projection := dot(axis, it);
        if min > projection min = projection;
        if max < projection max = projection;
    }

    return min, max;
}

collision_obb_obb :: (a: OBB, b: OBB) -> Vector3, float, bool {
    collision_normal:  Vector3;
    collision_depth := FLOAT32_MAX;

    axes := get_sat_axes(a, b);
    for axis: axes {
        a_min, a_max := get_projected_interval(a, axis);
        b_min, b_max := get_projected_interval(b, axis);

        intervals_are_overlaping := !(b_min > a_max || a_min > b_max);
        if !intervals_are_overlaping return collision_normal, collision_depth, false;

        depth := (a_max - a_min + b_max - b_min) - (max(a_max, b_max) - min(a_min, b_min));
        flip  := (b_min < a_min);

        if depth > 0.0 && depth < collision_depth {
            collision_depth = depth;
            collision_normal  = ifx flip then -axis else axis;
        }
    }

    return collision_normal, collision_depth, true;
}

get_closest_point :: (point: Vector3, plane: Plane) -> Vector3 {
	distance := dot(point - plane.position, plane.normal);
	closest  := point - distance * plane.normal;
	return closest;
}

get_normal :: (using quad: Quad) -> Vector3 {
    return normalize(cross(b - a, c - b));
}

plane_from_quad :: (using quad: Quad) -> Plane {
    return .{ quad.a, get_normal(quad) };
}

is_colliding :: (a: Vector3, b: Quad) -> bool #symmetric {
    n  := get_normal(b);
    d1 := dot(cross(a - b.a, b.b - b.a), n);
    d2 := dot(cross(a - b.b, b.c - b.b), n);
    d3 := dot(cross(a - b.c, b.d - b.c), n);
    d4 := dot(cross(a - b.d, b.a - b.d), n);

    EPSILON :: 0.0001;
    return d1 <= 0.0 && d2 <= 0.0 && d3 <= 0.0 && d4 <= 0.0 && abs(dot(a - b.a, n)) < EPSILON;
}

get_collision_point :: (segment: Segment, plane: Plane, segment_a_is_valid := true, segment_b_is_valid := true) -> Vector3, bool {
    collision_point: Vector3;

    segment_vector := segment.b - segment.a;

    d0 := dot(plane.normal, segment.a);
    d1 := dot(plane.normal, segment_vector);
    d2 := dot(plane.normal, plane.position);

    EPSILON :: 0.0001;
    segment_and_plane_are_parallel := abs(d1) < EPSILON;
    if segment_and_plane_are_parallel return collision_point, false;
    
    t := (d2 - d0) / d1;

    if !segment_a_is_valid && t == 0.0 return collision_point, false;
    if !segment_b_is_valid && t == 1.0 return collision_point, false;

    collision_point_is_inside_segment := t >= 0.0 && t <= 1.0;
    if !collision_point_is_inside_segment return collision_point, false;

    collision_point = segment.a + segment_vector * t;

    return collision_point, true;
}

get_collision_point :: (segment: Segment, quad: Quad, segment_a_is_valid := true, segment_b_is_valid := true) -> Vector3, bool {
    collision_point, ok := get_collision_point(segment, plane_from_quad(quad), segment_a_is_valid, segment_b_is_valid);

    if !ok || !is_colliding(collision_point, quad) return collision_point, false;

    return collision_point, ok;
}

get_collision_points :: (a: OBB, b: Plane) -> [6] Vector3, int {
    result: [6] Vector3;
    count: int;

    edges := get_edges(a);

    for edge: edges {
        collision_point, ok := get_collision_point(edge, b, segment_a_is_valid = false, segment_b_is_valid = it_index < 8);
        if !ok continue;

        result[count] = collision_point;
        count += 1;
    }

    return result, count;
}

get_collision_points :: (a: OBB, b: Quad) -> [6] Vector3, int {
    result: [6] Vector3;
    count: int;

    edges := get_edges(a);

    for edge: edges {
        collision_point, ok := get_collision_point(edge, b, segment_a_is_valid = false, segment_b_is_valid = it_index < 8);
        if !ok continue;

        result[count] = collision_point;
        count += 1;
    }

    return result, count;
}

collision_sphere_obb :: (a: Vector3, r: float, obb: OBB) -> bool {
    return distance(a, closest_point_on_obb(obb, a)) <= r;
}

closest_point_on_obb :: (obb: OBB, point: Vector3) -> Vector3 {
    axes := get_axes(obb);
    translation := point - obb.position;

    dx := clamp(dot(translation, axes[0]), -obb.extents.x, obb.extents.x);
    dy := clamp(dot(translation, axes[1]), -obb.extents.y, obb.extents.y);
    dz := clamp(dot(translation, axes[2]), -obb.extents.z, obb.extents.z);

    return obb.position + axes[0] * dx + axes[1] * dy + axes[2] * dz;
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