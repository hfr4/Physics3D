Shape_Kind :: enum {
    SPHERE;
    BOX;
}

Shape :: struct {
    kind:           Shape_Kind;
    center_of_mass: Vector3;
}
