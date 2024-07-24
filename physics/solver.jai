solve :: (using contact: Narrowphase_Contact) {
    world_point_on_A    := local_to_world(A, local_point_on_A);
    world_point_on_B    := local_to_world(B, local_point_on_B);

    ra               := world_point_on_A - center_of_mass_local(A);
    rb               := world_point_on_B - center_of_mass_local(B);

    tensor_a         := inertia_tensor_inv_world(A);
    tensor_b         := inertia_tensor_inv_world(B);

    angular_ja       := cross(tensor_a * cross(ra, normal), ra);
    angular_jb       := cross(tensor_b * cross(rb, normal), rb);
    angular_factor   := dot(angular_ja + angular_jb, normal);

    vel_a            := A.linear_velocity + cross(A.angular_velocity, ra);
    vel_b            := B.linear_velocity + cross(B.angular_velocity, rb);
    vel_ab           := vel_a - vel_b;

    elasticity       := A.elasticity * B.elasticity;
    impulse_j        := (1.0 + elasticity) * dot(vel_ab, normal) / (A.inv_mass + B.inv_mass + angular_factor);
    impulse_j_vec    := impulse_j * normal;

    apply_impulse_at_point(A, -impulse_j_vec, world_point_on_A);
    apply_impulse_at_point(B,  impulse_j_vec, world_point_on_B);

    friction         := A.friction * B.friction;
    vel_norm         := normal * dot(normal, vel_ab);
    vel_tang         := vel_ab - vel_norm;
    vel_tang_normal  := normalize(vel_tang);

    inertia_a        := cross(tensor_a * cross(ra, vel_tang_normal), ra);
    inertia_b        := cross(tensor_b * cross(rb, vel_tang_normal), rb);
    inv_inertia      := dot(inertia_a + inertia_b, vel_tang_normal);

    reduced_mass     := 1.0 / (A.inv_mass + B.inv_mass + inv_inertia);
    impulse_friction := vel_tang * reduced_mass * friction;

    apply_impulse_at_point(A, -impulse_friction, world_point_on_A);
    apply_impulse_at_point(B,  impulse_friction, world_point_on_B);

    // Move colliding objects outside of each other
    tA := A.inv_mass / (A.inv_mass + B.inv_mass);
    tB := B.inv_mass / (A.inv_mass + B.inv_mass);
    ds := world_point_on_B - world_point_on_A;

    A.position += ds * tA;
    B.position -= ds * tB;
}