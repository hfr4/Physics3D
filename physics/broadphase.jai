Broadphase_Contact :: struct {
    A: *Body;
    B: *Body;
}

get_broadphase_contacts :: (using world: World) -> [..] Broadphase_Contact {
    contacts: [..] Broadphase_Contact;

    for i: 0..bodies.count - 2 {
        for j: i + 1..bodies.count - 1 {
            if collision_aabb_aabb(get_aabb(bodies[i]), get_aabb(bodies[j])) && !(is_static(bodies[i]) && is_static(bodies[j])) {
                array_add(*contacts, .{ bodies[i], bodies[j] });
            }
        }
    }

    return contacts;
}
