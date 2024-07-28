World :: struct {
    bodies: [..] *Body;
}

deinit :: (using world: *World) {
    array_reset(*bodies);
}

update :: (using world: *World, dt: float) {
    broadphase_contacts := get_broadphase_contacts(world);
    broadphase_contacts.allocator = temp;

    narrowphase_contacts := get_narrowphase_contacts(broadphase_contacts);
    narrowphase_contacts.allocator = temp;

    for narrowphase_contacts solve(it);

    for bodies update(it, dt);
}

apply_gravity :: (using world: *World, gravity: Vector3 = .{ 0, -9.8, 0 }) {
    for bodies {
        impulse := gravity * (1.0 / it.inv_mass) * 0.01;
        apply_linear_impulse(it, impulse);
    }
}