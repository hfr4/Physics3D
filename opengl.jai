Vertex :: struct {
    position: Vector3;
    texcoord: Vector2;
    normal:   Vector3;
    color:    Vector4;
}

Gl_Buffer_Object :: struct {
    vao: GLuint;
    vbo: GLuint;
}

make_buffer_object :: (vertices: [] Vertex) -> Gl_Buffer_Object {
    buffer_object: Gl_Buffer_Object;

    glGenVertexArrays(1, *buffer_object.vao);
    glGenBuffers(1, *buffer_object.vbo);

    glBindVertexArray(buffer_object.vao);
    defer glBindVertexArray(0);
    
    glBindBuffer(GL_ARRAY_BUFFER, buffer_object.vbo);
    defer glBindBuffer(GL_ARRAY_BUFFER, 0);

    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * vertices.count, vertices.data, GL_STREAM_DRAW);

    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);
    glEnableVertexAttribArray(3);

    offset: *Vertex;
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.position);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.texcoord);
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.normal);
    glVertexAttribPointer(3, 4, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.color);

    return buffer_object;
}

make_texture :: (filename: string) -> GLuint {
    stbi :: #import "stb_image";

    texture_w, texture_h, channels: s32;
    texture_data := stbi.stbi_load(temp_c_string(filename), *texture_w, *texture_h, *channels, 0);
    defer stbi.stbi_image_free(texture_data);

    texture: GLuint;
    glGenTextures(1, *texture);

    glBindTexture(GL_TEXTURE_2D, texture);
    defer glBindTexture(GL_TEXTURE_2D, 0);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture_w, xx texture_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, texture_data);

    return texture;
}

make_shader :: (filename: string) -> GLuint {
    LOG_BUFFER_SIZE :: 512;

    make_shader_object :: (shader: string, prefix: string, shader_type : GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        shaders: [2] *u8;
        shaders[0] = prefix.data;
        shaders[1] = shader.data;
        
        lengths: [2] s32;
        lengths[0] = xx prefix.count;
        lengths[1] = xx shader.count;

        glShaderSource(shader_object, 2, shaders.data, lengths.data);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log_data: [LOG_BUFFER_SIZE] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            assert(false, to_string(log_data.data));
            return 0;
        }

        return shader_object;
    }

    PREFIX_V :: #string END
    #version 330 core
    #define VERTEX_SHADER
    END

    PREFIX_F :: #string END
    #version 330 core
    #define FRAGMENT_SHADER
    END

    shader   := read_entire_file(filename,, temp);
    v_shader := make_shader_object(shader, PREFIX_V, GL_VERTEX_SHADER);
    f_shader := make_shader_object(shader, PREFIX_F, GL_FRAGMENT_SHADER);
    defer glDeleteShader(v_shader);
    defer glDeleteShader(f_shader);

    program := glCreateProgram();
    glAttachShader(program, v_shader);
    glAttachShader(program, f_shader);
    glLinkProgram(program);

    success: GLint;
    glGetProgramiv(program, GL_LINK_STATUS, *success);

    if !success then {
        log_data: [LOG_BUFFER_SIZE] u8;
        glGetProgramInfoLog(program, log_data.count, null, log_data.data);
        assert(false, to_string(log_data.data));
        return 0;
    } 

    return program;
}

make_vertices_from_obj :: (filename: string) -> [..] Vertex {
    #import "String";

    vertices: [..] Vertex;

    obj_string, ok := read_entire_file(filename,, temp); 
    assert(ok);

    positions:  [..] Vector3;
    texcoords:  [..] Vector2;
    normals:    [..] Vector3;
    faces:      [..][3][3] int;

    positions.allocator = temp;
    texcoords.allocator = temp;
    normals.allocator   = temp;
    faces.allocator     = temp;

    lines := split(obj_string, "\n");

    for line: lines {
        words := split(line, " ");

        if words.count == 1 continue;

        if words[0] == {
            case "v";
                array_add(*positions, .{ string_to_float(words[1]), string_to_float(words[2]), string_to_float(words[3]) });
    
            case "vt";
                array_add(*texcoords, .{ string_to_float(words[1]), string_to_float(words[2]) });
    
            case "vn";
                array_add(*normals  , .{ string_to_float(words[1]), string_to_float(words[2]), string_to_float(words[3]) });
    
            case "f";
                // Fan triangulation
                for 3..words.count - 1 {
                    face: [3][3] int;

                    triangulated_face_indexes := int.[1, it - 1, it];

                    for index, i: triangulated_face_indexes {
                        substring_count :: (str: string, substring: string) -> int {
                            count: int;

                            cursor := 0;
                            while true {
                                index := find_index_from_left(str, substring, cursor);
                                if index == -1 break;
                                cursor = index + substring.count;
                                count += 1;
                            }

                            return count;
                        }
                            
                        dbl_slash_count := substring_count(words[index], "//");
                        slash_count     := substring_count(words[index], "/");

                        if dbl_slash_count == 1
                        {
                            indexs := split(words[index], "//");
                            face[i][0] = string_to_int(indexs[0]) - 1;
                            face[i][1] = -1;
                            face[i][2] = string_to_int(indexs[1]) - 1;
                        } 
                        else if slash_count == 2
                        {
                            indexs := split(words[index], "/");
                            face[i][0] = string_to_int(indexs[0]) - 1;
                            face[i][1] = string_to_int(indexs[1]) - 1;
                            face[i][2] = string_to_int(indexs[2]) - 1;
                        }
                        else if slash_count == 1
                        {
                            indexs := split(words[index], "/");
                            face[i][0] = string_to_int(indexs[0]) - 1;
                            face[i][1] = string_to_int(indexs[1]) - 1;
                            face[i][2] = -1;
                        }
                        else if slash_count == 0
                        {
                            face[i][0] = string_to_int(words[index]) - 1;
                            face[i][1] = -1;
                            face[i][2] = -1;
                        }
                    }

                    array_add(*faces, face);
                }
        }
    }

    for face: faces {
        v0, v1, v2: Vertex;

        if face[0][0] != -1  v0.position = positions[face[0][0]];
        if face[1][0] != -1  v1.position = positions[face[1][0]];
        if face[2][0] != -1  v2.position = positions[face[2][0]];

        if face[0][1] != -1  v0.texcoord = texcoords[face[0][1]];
        if face[1][1] != -1  v1.texcoord = texcoords[face[1][1]];
        if face[2][1] != -1  v2.texcoord = texcoords[face[2][1]];

        CALCULATE_VERTEX_NORMALS :: true;
        #if CALCULATE_VERTEX_NORMALS {
            triangle_normal :: (a: Vector3, b: Vector3, c: Vector3) -> Vector3 {
                return normalize(cross(b - a, c - b));
            }

            normal := triangle_normal(v0.position, v1.position, v2.position);

            v0.normal = normal;
            v1.normal = normal;
            v2.normal = normal;
        } else {
            if face[0][2] != -1  v0.normal = normals[face[0][2]];
            if face[1][2] != -1  v1.normal = normals[face[1][2]];
            if face[2][2] != -1  v2.normal = normals[face[2][2]];
        }

        v0.color = .{ 1, 1, 1, 1 };
        v1.color = .{ 1, 1, 1, 1 };
        v2.color = .{ 1, 1, 1, 1 };

        array_add(*vertices, v0, v1, v2);
    }

    return vertices;
}
