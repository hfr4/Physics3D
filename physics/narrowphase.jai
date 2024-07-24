Narrowphase_Contact :: struct {
    A:             *Body;
    B:             *Body;
    local_point_on_A: Vector3;
    local_point_on_B: Vector3;
    normal:        Vector3;  // In World Space coordinates
    depth:         float;    // positive when non-penetrating, negative when penetrating
}

get_narrowphase_contacts :: (broadphase_contacts: [..] Broadphase_Contact) -> [..] Narrowphase_Contact {
    narrowphase_contacts: [..] Narrowphase_Contact;

    for broadphase_contacts {
        contact: Narrowphase_Contact;
        ok: bool;

        if      it.A.shape.kind == .SPHERE && it.B.shape.kind == .SPHERE contact, ok = sphere_sphere_contact(it.A, it.B);
        else if it.A.shape.kind == .SPHERE && it.B.shape.kind == .BOX    contact, ok = sphere_box_contact(it.A, it.B);
        else if it.A.shape.kind == .BOX    && it.B.shape.kind == .SPHERE contact, ok = sphere_box_contact(it.B, it.A);
        else if it.A.shape.kind == .BOX    && it.B.shape.kind == .BOX    contact, ok = box_box_contact(it.A, it.B);
        
        if ok array_add(*narrowphase_contacts, contact);
    }

    return narrowphase_contacts;
}

sphere_sphere_contact :: (A: *Body, B: *Body) -> Narrowphase_Contact, bool {
    contact: Narrowphase_Contact;

    shape_a := cast(*Sphere_Shape) A.shape;
    shape_b := cast(*Sphere_Shape) B.shape;

    is_colliding := collision_sphere_sphere(A.position, shape_a.radius, B.position, shape_b.radius);
    if !is_colliding return contact, false;
    
    contact.A                = A;
    contact.B                = B;
    contact.normal           = normalize(B.position - A.position);
    contact.local_point_on_A = world_to_local(A, A.position + contact.normal * shape_a.radius);
    contact.local_point_on_B = world_to_local(B, B.position - contact.normal * shape_b.radius);
    contact.depth            = distance(contact.local_point_on_A, contact.local_point_on_B);

    return contact, true;
}

sphere_box_contact :: (A: *Body, B: *Body) -> Narrowphase_Contact, bool {
    contact: Narrowphase_Contact;

    shape_a := cast(*Sphere_Shape) A.shape;
    shape_b := cast(*Box_Shape)    B.shape;

    is_inside := collision_point_obb(A.position, .{ B.position, ToMat3(B.rotation), shape_b.size });
    point     := closest_point_on_obb(.{ B.position, ToMat3(B.rotation), shape_b.size }, A.position); 
    dist      := length(A.position - point);

    is_colliding := is_inside || dist <= shape_a.radius;
    if !is_colliding return contact, false;
    
    contact.A                = A;
    contact.B                = B;
    contact.normal           = ifx is_inside then normalize(point - A.position) else normalize(A.position - point);
    contact.local_point_on_A = world_to_local(A, A.position - contact.normal * shape_a.radius);
    contact.local_point_on_B = world_to_local(B, A.position - contact.normal * dist);
    contact.depth            = distance(contact.local_point_on_A, contact.local_point_on_B);

    return contact, true;
}

box_box_contact :: (A: *Body, B: *Body) -> Narrowphase_Contact, bool {
    contact: Narrowphase_Contact;

    world_point_on_A, world_point_on_B, is_colliding := EPA_Collision(A, B);
    if !is_colliding return contact, false;

    contact.A                = A;
    contact.B                = B;
    contact.normal           = normalize(world_point_on_B - world_point_on_A);
    contact.local_point_on_A = world_to_local(A, world_point_on_A);
    contact.local_point_on_B = world_to_local(B, world_point_on_B);
    contact.depth            = distance(contact.local_point_on_A, contact.local_point_on_B);

    return contact, true;
}
