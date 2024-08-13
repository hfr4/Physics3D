init_draw_stuff :: () {
    default_shader = make_shader("assets/shaders/default.glsl");

    vertices_sphere = make_vertices_from_obj("assets/obj/sphere.obj");
    vertices_box    = make_vertices_from_obj("assets/obj/box.obj");

    bo_sphere = make_buffer_object(vertices_sphere);
    bo_box    = make_buffer_object(vertices_box);
    bo_buffer = make_buffer_object(vertices_buffer);
}

draw_3d_point :: (pos: Vector3, color: Vector4 = .{ 1, 1, 1, 1 }, size := .2) {
    mat := make_transformation_matrix4(pos, .{ 0, 0, 0, 1 }, size);

    loc_mat := glGetUniformLocation(default_shader, "model_matrix");
    loc_col := glGetUniformLocation(default_shader, "model_color");

    glBindVertexArray(bo_sphere.vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_col, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx vertices_sphere.count);
}

draw_3d_obb :: (obb: OBB, color: Vector4 = .{ 1, 1, 1, 1 }) {
    mat := make_transformation_matrix4(obb.position, get_rotation(obb.rotation), obb.extents);

    loc_mat := glGetUniformLocation(default_shader, "model_matrix");
    loc_col := glGetUniformLocation(default_shader, "model_color");

    glBindVertexArray(bo_box.vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_col, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx vertices_box.count);
}

draw_3d_sphere :: (sphere: Sphere, color: Vector4 = .{ 1, 1, 1, 1 }) {
    mat := make_transformation_matrix4(sphere.position, .{ 0, 0, 0, 1 }, sphere.radius);

    loc_mat := glGetUniformLocation(default_shader, "model_matrix");
    loc_col := glGetUniformLocation(default_shader, "model_color");

    glBindVertexArray(bo_sphere.vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_col, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx vertices_sphere.count);
}

draw_3d_triangle :: (triangle: Triangle, color: Vector4) {
    add_triangle(triangle.a, triangle.b, triangle.c, color);
}

draw_3d_quad :: (quad: Quad, color: Vector4 = .{ 1, 1, 1, 1 }) {
    add_triangle(quad.a, quad.b, quad.c, color);
    add_triangle(quad.a, quad.c, quad.d, color);
}

draw_3d_segment :: (segment: Segment, color: Vector4 = .{ 1, 1, 1, 1 }, width := .02) {
    normal        := normalize(segment.b - segment.a);
    non_parallel  := ifx abs(normal.x) < abs(normal.y) then Vector3.{ 1, 0, 0 } else Vector3.{ 0, 1, 0 };
    perpendicular := cross(normal, non_parallel);

    c0 := cross(perpendicular, normal) * width;
    c1 := cross(c0, normal);
    c2 := cross(c1, normal);
    c3 := cross(c2, normal);

    p0 := segment.a + c0;
    p1 := segment.a + c1;
    p2 := segment.a + c2;
    p3 := segment.a + c3;

    p4 := segment.b + c0;
    p5 := segment.b + c1;
    p6 := segment.b + c2;
    p7 := segment.b + c3;

    add_triangle(p0, p1, p4, color);
    add_triangle(p1, p2, p5, color);
    add_triangle(p2, p3, p6, color);
    add_triangle(p3, p0, p7, color);
    add_triangle(p1, p4, p5, color);
    add_triangle(p2, p5, p6, color);
    add_triangle(p3, p6, p7, color);
    add_triangle(p0, p7, p4, color);
}

draw_3d_segment :: (a: Vector3, b: Vector3, color: Vector4 = .{ 1, 1, 1, 1 }, width := .02) {
    draw_3d_segment(Segment.{ a, b }, color, width);
}

draw_3d_plane :: (plane: Plane, color: Vector4 = .{ 1, 1, 1, 1 }) {
    draw_3d_segment(plane.position, plane.position + plane.normal * 3.0);

    non_parallel  := ifx abs(plane.normal.x) < abs(plane.normal.y) then Vector3.{ 1, 0, 0 } else Vector3.{ 0, 1, 0 };
    perpendicular := cross(plane.normal, non_parallel);

    c0 := cross(plane.normal, perpendicular);
    c1 := cross(c0, plane.normal);
    c2 := cross(c1, plane.normal);
    c3 := cross(c2, plane.normal);

    c0 = normalize(c0) * 5.0;
    c1 = normalize(c1) * 5.0;
    c2 = normalize(c2) * 5.0;
    c3 = normalize(c3) * 5.0;

    add_triangle(plane.position + c0, plane.position + c1, plane.position, color);
    add_triangle(plane.position + c1, plane.position + c2, plane.position, color);
    add_triangle(plane.position + c2, plane.position + c3, plane.position, color);
    add_triangle(plane.position + c3, plane.position + c0, plane.position, color);
}

draw_3d_buffer :: () #expand {
    model_matrix := Matrix4_Identity;
    model_color  := Vector4.{ 1, 1, 1, 1 };

    loc_mat := glGetUniformLocation(default_shader, "model_matrix");
    loc_col := glGetUniformLocation(default_shader, "model_color");

    glBindVertexArray(bo_buffer.vao);
    glBindBuffer(GL_ARRAY_BUFFER, bo_buffer.vbo);

    glUniformMatrix4fv(loc_mat, 1, false, xx *model_matrix);
    glUniform4fv(loc_col, 1, xx *model_color);

    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * vertices_buffer.count, vertices_buffer.data, GL_STREAM_DRAW);
    glDrawArrays(GL_TRIANGLES, 0, xx vertices_buffer.count);

    array_reset(*vertices_buffer);
}

#scope_file

add_triangle :: (a: Vector3, b: Vector3, c: Vector3, color: Vector4) #expand {
    triangle := Triangle.{ a, b, c };

    normal := get_normal(triangle);

    v0 := Vertex.{ a, .{}, normal, color };
    v1 := Vertex.{ b, .{}, normal, color };
    v2 := Vertex.{ c, .{}, normal, color };

    array_add(*vertices_buffer, v0, v1, v2);
}

#scope_export

vertices_sphere: [..] Vertex; 
vertices_box:    [..] Vertex; 
vertices_buffer: [..] Vertex;

bo_sphere:  Gl_Buffer_Object;
bo_box:     Gl_Buffer_Object;
bo_buffer:  Gl_Buffer_Object;


default_shader: GLuint;