Simplex :: struct {
    points: [4] Support_Point;
    count:  int;
}

make_simplex :: (points: ..Support_Point) -> Simplex {
    simplex: Simplex;

    for points add(*simplex, it);

    return simplex;
}

add :: (using simplex: *Simplex, point: Support_Point) {
    points[count] = point;
    count += 1;
}

Support_Point :: struct {
    on_A:     Vector3;
    on_B:     Vector3;
    position: Vector3;
}

make_support_point :: (A: Body, B: Body, direction: Vector3, bias: float = 0.0) -> Support_Point {
    point: Support_Point;

    farthest_point_in_this_direction :: (using body: Body, direction: Vector3, bias: float) -> Vector3 {
        if #complete kind == {
            case .SPHERE; 
                return position + direction * ( sphere.radius + bias );

            case .BOX;
                max_point := rotate(box.points[0], rotation) + position;
                max_dist  := dot(direction, max_point);
                
                for box.points {
                    point := rotate(it, rotation) + position;
                    dist  := dot(direction, point);

                    if dist > max_dist {
                        max_dist  = dist;
                        max_point = point;
                    }
                }
                
                return max_point + direction * bias;
        }
    }

    point.on_A     = farthest_point_in_this_direction(A,  normalize(direction), bias);
    point.on_B     = farthest_point_in_this_direction(B, -normalize(direction), bias);
    point.position = point.on_A - point.on_B;

    return point;
}

GJK_Collision :: (A: *Body, B: *Body) -> Simplex, bool {
    simplex: Simplex;
    
    direction := Vector3.{ 1, 0, 0 };                 // Arbitrary starting direction to get the ball rolling
    support   := make_support_point(A, B, direction); // Go as far as possible in search direction
    
    add(*simplex, support); 

    direction = support.position * -1.0; // Go in opposite direction (far side of origin)

    MAX_STEPS :: 50;

    steps := 0;
    while steps < MAX_STEPS {
        support = make_support_point(A, B, direction);

        // Didn't reach the origin i.e. no intersection (can't enclose the origin)
        if dot(support.position, direction) < 0.0 return simplex, false;

        add(*simplex, support);
        
        if contains_origin(*simplex, *direction) return simplex, true;
        
        steps += 1;
    }

    return simplex, false;
}

#scope_file

ORIGIN :: Vector3.{ 0, 0, 0 };

contains_origin :: (simplex: *Simplex, direction: *Vector3) -> bool {
    if       simplex.count == 2 return line\      _contains_origin(simplex, direction);
    else if  simplex.count == 3 return triangle\  _contains_origin(simplex, direction);
    else if  simplex.count == 4 return tetrahedron_contains_origin(simplex, direction);

    return false;
}

line_contains_origin :: (simplex: *Simplex, direction: *Vector3) -> bool {
    A := simplex.points[1]; // A is the point we just added, the direction that we moved
    B := simplex.points[0]; // B is further from origin than A, because A went past the origin, so B cannot be the closest point

    AO := ORIGIN - A.position;
    AB := B.position  - A.position;    

    // AB and AO are in the same direction, therefore the origin is in the edge region.
    if dot(AO, AB) > 0.0 { 
        direction.* = cross(cross(AB, AO), AB); // cross the two vectors twice to get the vector perpendicular to AB in the direction AO
    }

    // A is closest feature to the origin
    else { 
        simplex.*   = make_simplex(A);
        direction.* = AO;
    }

    return false;
}

triangle_contains_origin :: (simplex: *Simplex, direction: *Vector3) -> bool {
    A := simplex.points[2]; // A is always the last point inserted into the simplex. Because of this, assumptions can be made as to which feature is closest to the origin.
    B := simplex.points[1];
    C := simplex.points[0];

    AO := ORIGIN - A.position;
    AB := B.position  - A.position;
    AC := C.position  - A.position;

    ABC := cross(AB, AC);

    // Origin is in perpendicular direction of AC. This narrows down the closest feature to either AC, AB or A
    if dot(cross(ABC, AC), AO) > 0.0 {

        // AC is the closest feature
        if dot(AC, AO) > 0.0 {
            simplex.*   = make_simplex(C, A);
            direction.* = cross(cross(AC, AO), AC); // perpendicular of AC facing in direction of origin
        }

        // AB is the closest feature
        else if dot(AB, AO) > 0.0 {
            simplex.*   = make_simplex(B, A);
            direction.* = cross(cross(AB, AO), AB); // perpendicular of AB facing in direction of origin
        }

        // A is the closest feature
        else {
            simplex.*   = make_simplex(A);
            direction.* = AO; // Search in direction from A to origin
        }
    }

    else if dot(cross(AB, ABC), AO) > 0.0 {
        
        // AB is the closest feature
        if dot(AB, AO) > 0.0 {
            simplex.*   = make_simplex(B, A);
            direction.* = cross(cross(AB, AO), AB); // perpendicular of AB facing in direction of origin
        }

        // A is the closest feature
        else {
            simplex.*   = make_simplex(A);
            direction.* = AO; // Search in direction from A to origin
        }
    }

    // Origin is above the triangle plane (i.e. direction of triangle's normal)
    else if dot(ABC, AO) > 0.0 {
        simplex.*   = make_simplex(C, B, A);
        direction.* = ABC;
    }

    // Origin is below the triangle plane (opposite direction of triangle's normal)
    else {
        simplex.*   = make_simplex(B, C, A);
        direction.* = -ABC;
    }
    
    return false;
}    

tetrahedron_contains_origin :: (simplex: *Simplex, direction: *Vector3) -> bool {
    A := simplex.points[3];
    B := simplex.points[2];
    C := simplex.points[1];
    D := simplex.points[0];

    AO := ORIGIN - A.position;
    AB := B.position  - A.position;
    AC := C.position  - A.position;
    AD := D.position  - A.position;

    ABC := cross(AB, AC);
    ACD := cross(AC, AD);
    ADB := cross(AD, AB);

    // Just 3 triangle checks, as the face BCD can't possibly be the closest feature as A was the last added point to the simplex.

    // Origin is the the direction of the normal of ABC
    if dot(ABC, AO) > 0.0 {
        simplex.* = make_simplex(C, B, A);

        return triangle_contains_origin(simplex, direction);
    }

    // Origin is the the direction of the normal of ADB
    else if dot(ADB, AO) > 0.0 {
        simplex.* = make_simplex(B, D, A);

        return triangle_contains_origin(simplex, direction);
    }

    // Origin is the the direction of the normal of ACD
    else if dot(ACD, AO) > 0.0 {
        simplex.* = make_simplex(D, C, A);

        return triangle_contains_origin(simplex, direction);
    }

    // The origin is INSIDE the tetrahedron
    return true;
}
