EPA_Collision :: (A: *Body, B: *Body) -> Vector3, Vector3, bool {
    simplex: Simplex;
    is_colliding: bool;

    // GJK 

    direction := Vector3.{ 1, 1, 1 };
    support   := make_support_point(A, B, direction);
    AddPoint(*simplex, support);

    direction = support.pos * -1.0;

    min_dist := FLOAT32_MAX;
    while true {
        support = make_support_point(A, B, direction);
        if HasPoint(simplex, support) break;

        AddPoint(*simplex, support);

        if dot(direction, support.pos) < 0.0 break;

        lambdas:, direction, is_colliding = SimplexSignedVolumes(simplex);
        if is_colliding break;

        dist := length_squared(direction);
        if dist >= min_dist break;
        min_dist = dist;

        Sort(*simplex, lambdas);

        is_colliding = (simplex.count == 4);
        if is_colliding break;
    }

    if !is_colliding return .{}, .{}, false;

    // Check that we have a 3-simplex (EPA expects a tetrahedron)

    if simplex.count == 1 {
        direction := simplex[0].pos * -1.0;
        support   := make_support_point(A, B, direction);
        AddPoint(*simplex, support);
    }

    if simplex.count == 2 {
        ab := simplex[1].pos - simplex[0].pos;
        u, v := GetOrtho(ab);

        direction := u;
        support   := make_support_point(A, B, direction);
        AddPoint(*simplex, support);
    }

    if simplex.count == 3 {
        ab := simplex[1].pos - simplex[0].pos;
        ac := simplex[2].pos - simplex[0].pos;

        direction := cross(ab, ac);
        support   := make_support_point(A, B, direction);
        AddPoint(*simplex, support);
    }

    BIAS :: 0.001;

    world_point_on_A, world_point_on_B := EPA_Expand(A, B, simplex, BIAS);

    return world_point_on_A, world_point_on_B, true;
}

#scope_file

Support_Point :: struct {
    on_a: Vector3; // Point on A
    on_b: Vector3; // Point on B
    pos:  Vector3; // Point on minkowski sum
}

Simplex :: struct {
    points: [4] Support_Point;
    count: int;
}

operator *[] :: (simplex: *Simplex, index: int) -> *Support_Point {
    return *simplex.points[index];
}

Triangle_Indices :: struct {
    a: int;
    b: int;
    c: int;
}

Edge_Indices :: struct {
    a: int;
    b: int;
}

EPA_Expand :: (bodyA: *Body, bodyB: *Body, simplex: Simplex, bias: float) -> Vector3, Vector3 {
    // Expand the simplex by the bias amount

    center := GetCenter(simplex);

    for 0..simplex.count - 1 {
        point     := *simplex[it];
        direction := normalize(point.pos - center); // ray from "center" to witness point

        simplex[it].on_a += direction * bias;
        simplex[it].on_b -= direction * bias;
        simplex[it].pos   = simplex[it].on_a - simplex[it].on_b;
    }

    // Initialize points and triangles

    points: [..] Support_Point;
    points.allocator = temp;
    array_add(*points, simplex[0], simplex[1], simplex[2], simplex[3]);

    triangles: [..] Triangle_Indices;
    triangles.allocator = temp;
    for i: 0..3 {
        j := (i + 1) % 4;
        k := (i + 2) % 4;
        l := (i + 3) % 4;

        tri := Triangle_Indices.{ i, j, k };

        // The unused point is always on the negative/inside of the triangle.. make sure the normal points away
        dist := SignedDistanceToTriangle(points, tri, points[l].pos);
        if dist > 0.0 Swap(*tri.a, *tri.b);
        
        array_add(*triangles, tri);
    }

    // Expand the simplex to find the closest face of the CSO to the origin

    while true {
        tri    := ClosestTriangleToPoint(points, triangles, .{ 0, 0, 0 });
        normal := TriangleNormal(points, tri);
        pt     := make_support_point(bodyA, bodyB, normal, bias);

        // if w already exists, then just stop because it means we can't expand any further
        if HasPoint(points, triangles, pt.pos) break;

        dist := SignedDistanceToTriangle(points, tri, pt.pos);
        if dist <= 0.0 break; // can't expand

        new_idx := points.count;
        array_add(*points, pt);

        // Remove Triangles that face this point
        for triangles {
            if SignedDistanceToTriangle(points, it, pt.pos) > 0.0  {
                remove it;
            }
        }
        if triangles.count == 0 break;
        
        // Find Dangling Edges
        edges := FindDanglingEdges(triangles);
        edges.allocator = temp;
        if edges.count == 0 break;
        
        // In theory the edges should be a proper CCW order so we only need to add 
        // the new point as 'a' in order to create new triangles that face away from origin
        for edges {
            tri := Triangle_Indices.{ new_idx, it.b, it.a };
    
            // Make sure it's oriented properly
            if SignedDistanceToTriangle(points, tri, center) > 0.0 {
                Swap(*tri.b, *tri.c);
            }

            array_add(*triangles, tri);
        }
    }

    ORIGIN :: Vector3.{ 0, 0, 0 };

    // Get the projection of the origin on the closest triangle
    tri     := ClosestTriangleToPoint(points, triangles, ORIGIN);
    coords  := BarycentricCoordinates(points[tri.a].pos, points[tri.b].pos, points[tri.c].pos, ORIGIN);
    pt_on_a := points[tri.a].on_a * coords.x + points[tri.b].on_a * coords.y + points[tri.c].on_a * coords.z;
    pt_on_b := points[tri.a].on_b * coords.x + points[tri.b].on_b * coords.y + points[tri.c].on_b * coords.z;

    return pt_on_a, pt_on_b;
}

make_support_point :: (a: Body, b: Body, dir: Vector3, bias: float = 0.0) -> Support_Point {
    point: Support_Point;
    
    point.on_a = get_support_point(a,  normalize(dir), bias);
    point.on_b = get_support_point(b, -normalize(dir), bias);
    point.pos  = point.on_a - point.on_b;

    return point;
}

SimplexSignedVolumes :: (using simplex: Simplex) -> Vector4, Vector3, bool {
    lambdas: Vector4;
    if count == {
        case 2; v := SignedVolume1D(points[0].pos, points[1].pos);                               lambdas = .{ v.x, v.y, 0.0, 0.0 };
        case 3; v := SignedVolume2D(points[0].pos, points[1].pos, points[2].pos);                lambdas = .{ v.x, v.y, v.z, 0.0 };
        case 4; v := SignedVolume3D(points[0].pos, points[1].pos, points[2].pos, points[3].pos); lambdas = .{ v.x, v.y, v.z, v.w };
    }

    direction: Vector3;
    for 0..count - 1 { 
        direction -= points[it].pos * lambdas.component[it]; 
    }

    EPSILON :: 0.0001 * 0.0001;
    is_colliding := length_squared(direction) < EPSILON;
    
    return lambdas, direction, is_colliding;
}

SignedVolume1D :: (a: Vector3, b: Vector3) -> Vector2 {
    ORIGIN :: Vector3.{ 0, 0, 0 };

    // Find the axis with the greatest distance between points a and b
    axis_index, max_dist := GreatestDistAxisIndex(a, b);

    // Project the origin onto the line ab
    ab := b - a;
    projected_origin := a + ab * (dot(ab, ORIGIN - a) / dot(ab, ab));

    // Extract the relevant coordinates along the dominant axis
    a_coord      := a.component[axis_index];
    b_coord      := b.component[axis_index];
    origin_coord := projected_origin.component[axis_index];

    // Calculate barycentric coordinates
    barycentric_coords: Vector2;

    barycentric_coords.x = clamp((b_coord - origin_coord) / max_dist, 0.0, 1.0);
    barycentric_coords.y = clamp((origin_coord - a_coord) / max_dist, 0.0, 1.0);

    return barycentric_coords;
}

SignedVolume2D :: (a: Vector3, b: Vector3, c: Vector3) -> Vector3 {
    // Find the axis with the greatest projected area
    idx, max_area := GreatestAreaAxisIndex(a, b, c);

    // Project onto the appropriate axis
    x := (idx + 1) % 3;
    y := (idx + 2) % 3;
    s := Vector2.[ .{ a.component[x], a.component[y] }, .{ b.component[x], b.component[y] }, .{ c.component[x], c.component[y] } ];

    n  := TriangleNormal(a, b, c);
    p0 := n * dot(a, n) / dot(n, n);
    p  := Vector2.{ p0.component[x], p0.component[y] };

    // Get the sub-areas of the triangles formed from the projected origin and the edges
	areas: Vector3;
	areas.x = Vec2Cross(s[1] - p, s[2] - p);
	areas.y = Vec2Cross(s[2] - p, s[0] - p);
	areas.z = Vec2Cross(s[0] - p, s[1] - p);

    // If the projected origin is inside the triangle, then return the barycentric points
    origin_inside := CompareSigns(max_area, areas.x) && 
                     CompareSigns(max_area, areas.y) && 
                     CompareSigns(max_area, areas.z);

    // If inside, return normalized sub-volumes as barycentric coordinates
    if origin_inside return areas / max_area;
    

    // If we make it here, then we need to project onto the edges and determine the closest point
    barycentric_coords: Vector3;

    vertices := Vector3.[ a, b, c ];
    min_dist := FLOAT32_MAX;
    for i: 0..2 {
        j := (i + 1) % 3;
        k := (i + 2) % 3;

        // Get barycentric coordinates of projection on current edge
        edge_coords := SignedVolume1D(vertices[j], vertices[k]);

        // Calculate the actual point on the edge
        projected_point := vertices[j] * edge_coords.x + 
                           vertices[k] * edge_coords.y;

        // Check if this is the closest edge so far
        dist := length_squared(projected_point);

        if dist < min_dist {
            min_dist = dist;
            barycentric_coords.component[i] = 0.0;
            barycentric_coords.component[j] = edge_coords.x;
            barycentric_coords.component[k] = edge_coords.y;
        }
    }

    return barycentric_coords;
}

SignedVolume3D :: (a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Vector4 {
    tetrahedron_matrix := Matrix4.{
        a.x, b.x, c.x, d.x,
        a.y, b.y, c.y, d.y,
        a.z, b.z, c.z, d.z,
        1.0 , 1.0 , 1.0 , 1.0,
    };

    // Calculate cofactors of the last row
    // These represent signed volumes of sub-tetrahedra formed with the origin
    sub_volumes := Vector4.{ 
        Cofactor(tetrahedron_matrix, 3, 0), 
        Cofactor(tetrahedron_matrix, 3, 1), 
        Cofactor(tetrahedron_matrix, 3, 2), 
        Cofactor(tetrahedron_matrix, 3, 3) 
    };

    total_volume := sub_volumes.x + sub_volumes.y + sub_volumes.z + sub_volumes.w;

    // Check if the origin is inside the tetrahedron
    origin_inside := CompareSigns(total_volume, sub_volumes.x) && 
                     CompareSigns(total_volume, sub_volumes.y) && 
                     CompareSigns(total_volume, sub_volumes.z) && 
                     CompareSigns(total_volume, sub_volumes.w);
    
    // If inside, return normalized sub-volumes as barycentric coordinates
    if origin_inside return sub_volumes * (1.0 / total_volume);

    // If the origin is outside, project it onto the closest face
    barycentric_coords: Vector4;

    vertices := Vector3.[ a, b, c, d ];
    min_dist := FLOAT32_MAX;
    for i: 0..3 {
        j := (i + 1) % 4;
        k := (i + 2) % 4;
        l := (i + 3) % 4; // Unused vertex

        // Get barycentric coordinates of projection on current face
        face_coords := SignedVolume2D(vertices[i], vertices[j], vertices[k]);

        // Calculate the actual point on the face
        projected_point := vertices[i] * face_coords.x + 
                           vertices[j] * face_coords.y + 
                           vertices[k] * face_coords.z;

        // Check if this is the closest face so far
        dist := length_squared(projected_point);

        if dist < min_dist {
            min_dist = dist;
            barycentric_coords.component[i] = face_coords.x;
            barycentric_coords.component[j] = face_coords.y;
            barycentric_coords.component[k] = face_coords.z;
            barycentric_coords.component[l] = 0.0; // Unused vertex has zero weight
        }
    }

    return barycentric_coords;
}

HasPoint :: (using simplex: Simplex, point: Support_Point) -> bool {
    EPSILON :: 0.0001;

    for 0..3 {
        dist := points[it].pos - point.pos;
        if length_squared(dist) < EPSILON return true;
    }

    return false;
}

AddPoint :: (using simplex: *Simplex, point: Support_Point) {
    points[count] = point;
    count += 1;
}

Sort :: (using simplex: *Simplex, lambdas: Vector4) {
    sorted: Simplex;

    if lambdas.x != 0.0 AddPoint(*sorted, points[0]);
    if lambdas.y != 0.0 AddPoint(*sorted, points[1]);
    if lambdas.z != 0.0 AddPoint(*sorted, points[2]);
    if lambdas.w != 0.0 AddPoint(*sorted, points[3]);

    simplex.* = sorted;
}

GetCenter :: (using simplex: Simplex) -> Vector3 {
    return (points[0].pos + points[1].pos + points[2].pos + points[3].pos) / 4.0;
}

TriangleNormal :: (a: Vector3, b: Vector3, c: Vector3) -> Vector3 {
    return cross(b - a, c - a);
}

BarycentricCoordinates :: (a: Vector3, b: Vector3, c: Vector3, point: Vector3) -> Vector3 {
    s1 := a - point;
    s2 := b - point;
    s3 := c - point;

    // Find the axis with the greatest projected area

    idx, max_area := GreatestAreaAxisIndex(s1, s2, s3);

    // Project onto the appropriate axis

    x := (idx + 1) % 3;
    y := (idx + 2) % 3;
    s := Vector2.[ .{ s1.component[x], s1.component[y] }, .{ s2.component[x], s2.component[y] }, .{ s3.component[x], s3.component[y] } ];

    n  := TriangleNormal(s1, s2, s3);
    p0 := n * dot(s1, n) / length_squared(n);
    p := Vector2.{ p0.component[x], p0.component[y] };

    // Get the sub-areas of the triangles formed from the projected origin and the edges

	areas: Vector3;
	areas.x = Vec2Cross(s[1] - p, s[2] - p);
	areas.y = Vec2Cross(s[2] - p, s[0] - p);
	areas.z = Vec2Cross(s[0] - p, s[1] - p);

    coords := areas / max_area;
    if isnan(coords.x) || isnan(coords.y) || isnan(coords.z) {
        coords = .{ 1, 0, 0 };
    }

    return coords;
}

GreatestDistAxisIndex :: (s1: Vector3, s2: Vector3) -> int, float {
    index: int;
    max_dist: float;

    for 0..2 {
        dist := s2.component[it] - s1.component[it];

        if dist * dist > max_dist * max_dist { 
            max_dist = dist;
            index    = it;
        }
    }

    return index, max_dist;
}

GreatestAreaAxisIndex :: (s1: Vector3, s2: Vector3, s3: Vector3) -> int, float {
    index: int;
    max_area: float;

    for i: 0..2 {
        j := (i + 1) % 3;
        k := (i + 2) % 3;

        a := s2.component[j] - s1.component[j];
        b := s3.component[k] - s1.component[k];
        c := s3.component[j] - s1.component[j];
        d := s2.component[k] - s1.component[k];

        area := a * b - c * d;

        if area * area > max_area * max_area {
            max_area = area;
            index    = i;
        }
    }

    return index, max_area;
}

TriangleNormal :: (points: [] Support_Point, tri: Triangle_Indices) -> Vector3 {
    ab := points[tri.b].pos - points[tri.a].pos;
    ac := points[tri.c].pos - points[tri.a].pos;

    return normalize(cross(ab, ac));
}

SignedDistanceToTriangle :: (points: [] Support_Point, tri: Triangle_Indices, point: Vector3) -> float {
    ap := point - points[tri.a].pos;
    n  := TriangleNormal(points, tri);

    return dot(n, ap);
}

HasPoint :: (points: [] Support_Point, triangles: [] Triangle_Indices, point: Vector3) -> bool {
    EPSILON :: 0.001 * 0.001;

    for triangles {
        if length_squared(point - points[it.a].pos) < EPSILON return true;
        if length_squared(point - points[it.b].pos) < EPSILON return true;
        if length_squared(point - points[it.c].pos) < EPSILON return true;
    }

    return false;
}

ClosestTriangleToPoint :: (points: [] Support_Point, triangles: [] Triangle_Indices, point: Vector3) -> Triangle_Indices {
    index: int;

    min_dist := FLOAT32_MAX;
    for triangles {
        dist := SignedDistanceToTriangle(points, it, point);

        if dist * dist < min_dist * min_dist {
            min_dist = dist;
            index    = it_index;
        }
    }

    return triangles[index];
}

FindDanglingEdges :: (triangles: [] Triangle_Indices) -> [..] Edge_Indices  {
    edges: [..] Edge_Indices;

    for ti, i: triangles {
        counts: [3] int;

        ei := Edge_Indices.[ .{ ti.a, ti.b }, .{ ti.b, ti.c }, .{ ti.c, ti.a } ];

        for tj, j: triangles {
            if i == j continue;
            
            ej := Edge_Indices.[ .{ tj.a, tj.b }, .{ tj.b, tj.c }, .{ tj.c, tj.a } ];

            for k: 0..2 {
                for l: 0..2 {
                    if (ei[k].a == ej[l].a && ei[k].b == ej[l].b) || (ei[k].a == ej[l].b && ei[k].b == ej[l].a) {
                        counts[k] += 1;
                    }
                }
            }
        }

        // An edge that isn't shared is dangling 
        for 0..2 {
            if !counts[it] array_add(*edges, ei[it]);
        }
    }

    return edges;
}
