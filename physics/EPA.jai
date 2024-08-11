EPA_Collision :: (A: *Body, B: *Body) -> Vector3, Vector3, bool {
    simplex, is_colliding := GJK_Collision(A, B);
    if !is_colliding return .{}, .{}, false;

    // Check that we have a 3-simplex (EPA expects a tetrahedron)

    if simplex.count == 1 {
        direction := simplex.points[0].position * -1.0;
        support   := make_support_point(A, B, direction);
        add(*simplex, support);
    }

    if simplex.count == 2 {
        ab := simplex.points[1].position - simplex.points[0].position;
        u, v := GetOrtho(ab);

        direction := u;
        support   := make_support_point(A, B, direction);
        add(*simplex, support);
    }

    if simplex.count == 3 {
        ab := simplex.points[1].position - simplex.points[0].position;
        ac := simplex.points[2].position - simplex.points[0].position;

        direction := cross(ab, ac);
        support   := make_support_point(A, B, direction);
        add(*simplex, support);
    }

    BIAS :: 0.001;

    world_point_on_A, world_point_on_B := expand_polytope(A, B, simplex, BIAS);

    return world_point_on_A, world_point_on_B, true;
}

#scope_file

expand_polytope :: (A: *Body, B: *Body, simplex: Simplex, bias: float) -> Vector3, Vector3 {
    // Expand the simplex by the bias amount

    center := (
        simplex.points[0].position + 
        simplex.points[1].position + 
        simplex.points[2].position + 
        simplex.points[3].position
    ) / 4.0;

    for 0..simplex.count - 1 {
        point     := *simplex.points[it];
        direction := normalize(point.position - center); // ray from "center" to witness point

        point.on_A += direction * bias;
        point.on_B -= direction * bias;
        point.position   = point.on_A - point.on_B;
    }

    // Initialize points and triangles

    points: [..] Support_Point;
    points.allocator = temp;

    array_add(*points, simplex.points[0], simplex.points[1], simplex.points[2], simplex.points[3]);

    triangles: [..] Triangle_Indices;
    triangles.allocator = temp;

    for i: 0..3 {
        j := (i + 1) % 4;
        k := (i + 2) % 4;
        l := (i + 3) % 4;

        tri := Triangle_Indices.{ i, j, k };

        // The unused point is always on the negative/inside of the triangle.. make sure the normal points away
        dist := signed_distance_to_triangle(points, tri, points[l].position);
        if dist > 0.0 Swap(*tri.a, *tri.b);
        
        array_add(*triangles, tri);
    }

    // Expand the simplex to find the closest face of the CSO to the origin

    while true {
        tri    := closest_triangle_to_point(points, triangles, .{ 0, 0, 0 });
        normal := triangle_normal(points, tri);
        pt     := make_support_point(A, B, normal, bias);

        // if w already exists, then just stop because it means we can't expand any further
        if has_point(points, triangles, pt.position) break;

        dist := signed_distance_to_triangle(points, tri, pt.position);
        if dist <= 0.0 break; // can't expand

        new_idx := points.count;
        array_add(*points, pt);

        // Remove Triangles that face this point
        for triangles {
            if signed_distance_to_triangle(points, it, pt.position) > 0.0 {
                remove it;
            }
        }
        if triangles.count == 0 break;
        
        // Find Dangling Edges
        edges := find_dangling_edges(triangles);
        edges.allocator = temp;
        if edges.count == 0 break;
        
        // In theory the edges should be a proper CCW order so we only need to add 
        // the new point as 'a' in order to create new triangles that face away from origin
        for edges {
            tri := Triangle_Indices.{ new_idx, it.b, it.a };
    
            // Make sure it's oriented properly
            if signed_distance_to_triangle(points, tri, center) > 0.0 {
                Swap(*tri.b, *tri.c);
            }

            array_add(*triangles, tri);
        }
    }

    ORIGIN :: Vector3.{ 0, 0, 0 };

    // Get the projection of the origin on the closest triangle
    tri     := closest_triangle_to_point(points, triangles, ORIGIN);
    coords  := barycentric_coordinates(points[tri.a].position, points[tri.b].position, points[tri.c].position, ORIGIN);

    pt_on_A := points[tri.a].on_A * coords.x + points[tri.b].on_A * coords.y + points[tri.c].on_A * coords.z;
    pt_on_B := points[tri.a].on_B * coords.x + points[tri.b].on_B * coords.y + points[tri.c].on_B * coords.z;

    return pt_on_A, pt_on_B;
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

triangle_normal :: (points: [] Support_Point, tri: Triangle_Indices) -> Vector3 {
    ab := points[tri.b].position - points[tri.a].position;
    ac := points[tri.c].position - points[tri.a].position;

    return normalize(cross(ab, ac));
}

signed_distance_to_triangle :: (points: [] Support_Point, tri: Triangle_Indices, point: Vector3) -> float {
    ap := point - points[tri.a].position;
    n  := triangle_normal(points, tri);

    return dot(n, ap);
}

has_point :: (points: [] Support_Point, triangles: [] Triangle_Indices, point: Vector3) -> bool {
    EPSILON :: 0.001 * 0.001;

    for triangles {
        if length_squared(point - points[it.a].position) < EPSILON return true;
        if length_squared(point - points[it.b].position) < EPSILON return true;
        if length_squared(point - points[it.c].position) < EPSILON return true;
    }

    return false;
}

closest_triangle_to_point :: (points: [] Support_Point, triangles: [] Triangle_Indices, point: Vector3) -> Triangle_Indices {
    index: int;

    min_dist := FLOAT32_MAX;
    for triangles {
        dist := signed_distance_to_triangle(points, it, point);

        if dist * dist < min_dist * min_dist {
            min_dist = dist;
            index    = it_index;
        }
    }

    return triangles[index];
}

find_dangling_edges :: (triangles: [] Triangle_Indices) -> [..] Edge_Indices  {
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

barycentric_coordinates :: (a: Vector3, b: Vector3, c: Vector3, p: Vector3) -> Vector3 {
	coords: Vector3;

    v0 := b - a; 
    v1 := c - a; 
    v2 := p - a;
    
    d00 := dot(v0, v0);
    d01 := dot(v0, v1);
    d11 := dot(v1, v1);
    d20 := dot(v2, v0);
    d21 := dot(v2, v1);

	denom := (d00 * d11 - d01 * d01);

	coords.y = (d11 * d20 - d01 * d21) / denom; // v
    coords.z = (d00 * d21 - d01 * d20) / denom; // w
    coords.x = 1.0 - coords.y - coords.z;       // u

	return coords;
}
