Broadphase_Contact :: struct {
    A: *Body;
    B: *Body;
}

Octree :: struct {
    nodes:       [..] Octree_Node;
    max_capacity := 4;
    max_depth    := 4;
}

Octree_Node :: struct {
    aabb:     AABB;
    children: [8] int;
    is_leaf   := true;
    bodies:   [..] *Body;
}

init :: (using tree: *Octree, world: World) {
    if !world.bodies.count return;

    aabb := get_aabb(world.bodies[0]);
    for world.bodies  aabb = aabbs_aabb(aabb, get_aabb(it));
    aabb = fatt_aabb(aabb, 1.0);

    total_nodes_count := xx pow(8.0, xx max_depth) + 1;
    array_reserve(*tree.nodes, total_nodes_count);

    root := array_add(*tree.nodes);
    root.aabb = aabb;

    for world.bodies insert(tree, it);
}

insert :: (using tree: *Octree, body: *Body) {
    insert_recursive :: (using tree: *Octree, i: int, body: *Body, depth: int) { 
        using node := *nodes[i];

        if !is_leaf { 
            body_aabb := get_aabb(body);

            if      aabb_contains_aabb(nodes[children[0]].aabb, body_aabb) insert_recursive(tree, children[0], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[1]].aabb, body_aabb) insert_recursive(tree, children[1], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[2]].aabb, body_aabb) insert_recursive(tree, children[2], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[3]].aabb, body_aabb) insert_recursive(tree, children[3], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[4]].aabb, body_aabb) insert_recursive(tree, children[4], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[5]].aabb, body_aabb) insert_recursive(tree, children[5], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[6]].aabb, body_aabb) insert_recursive(tree, children[6], body, depth + 1);
            else if aabb_contains_aabb(nodes[children[7]].aabb, body_aabb) insert_recursive(tree, children[7], body, depth + 1);
            else                                                           array_add(*bodies, body);
        } else {
            array_add(*bodies, body);

            if bodies.count > max_capacity && depth < max_depth {
                is_leaf = false;

                children[0] = nodes.count + 0;
                children[1] = nodes.count + 1;
                children[2] = nodes.count + 2;
                children[3] = nodes.count + 3;
                children[4] = nodes.count + 4;
                children[5] = nodes.count + 5;
                children[6] = nodes.count + 6;
                children[7] = nodes.count + 7;

                node0 := array_add(*tree.nodes);
                node1 := array_add(*tree.nodes);
                node2 := array_add(*tree.nodes);
                node3 := array_add(*tree.nodes);
                node4 := array_add(*tree.nodes);
                node5 := array_add(*tree.nodes);
                node6 := array_add(*tree.nodes);
                node7 := array_add(*tree.nodes);

                half_size := (aabb.max - aabb.min) / 2.0;
                aabb_mid  := (aabb.min + aabb.max) / 2.0;

                node0.aabb = .{ min = .{ aabb.min.x, aabb.min.y, aabb.min.z }, max = .{ aabb.min.x, aabb.min.y, aabb.min.z } + half_size };
                node1.aabb = .{ min = .{ aabb.min.x, aabb_mid.y, aabb.min.z }, max = .{ aabb.min.x, aabb_mid.y, aabb.min.z } + half_size };
                node2.aabb = .{ min = .{ aabb_mid.x, aabb.min.y, aabb.min.z }, max = .{ aabb_mid.x, aabb.min.y, aabb.min.z } + half_size };
                node3.aabb = .{ min = .{ aabb_mid.x, aabb_mid.y, aabb.min.z }, max = .{ aabb_mid.x, aabb_mid.y, aabb.min.z } + half_size };
                node4.aabb = .{ min = .{ aabb.min.x, aabb.min.y, aabb_mid.z }, max = .{ aabb.min.x, aabb.min.y, aabb_mid.z } + half_size };
                node5.aabb = .{ min = .{ aabb.min.x, aabb_mid.y, aabb_mid.z }, max = .{ aabb.min.x, aabb_mid.y, aabb_mid.z } + half_size };
                node6.aabb = .{ min = .{ aabb_mid.x, aabb.min.y, aabb_mid.z }, max = .{ aabb_mid.x, aabb.min.y, aabb_mid.z } + half_size };
                node7.aabb = .{ min = .{ aabb_mid.x, aabb_mid.y, aabb_mid.z }, max = .{ aabb_mid.x, aabb_mid.y, aabb_mid.z } + half_size };

                for bodies {
                    body_aabb := get_aabb(it);

                    if      aabb_contains_aabb(nodes[children[0]].aabb, body_aabb) { insert_recursive(tree, children[0], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[1]].aabb, body_aabb) { insert_recursive(tree, children[1], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[2]].aabb, body_aabb) { insert_recursive(tree, children[2], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[3]].aabb, body_aabb) { insert_recursive(tree, children[3], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[4]].aabb, body_aabb) { insert_recursive(tree, children[4], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[5]].aabb, body_aabb) { insert_recursive(tree, children[5], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[6]].aabb, body_aabb) { insert_recursive(tree, children[6], it, depth + 1); remove it; }
                    else if aabb_contains_aabb(nodes[children[7]].aabb, body_aabb) { insert_recursive(tree, children[7], it, depth + 1); remove it; }
                }
            }
        }       
    }

    if !nodes.count return;

    insert_recursive(tree, 0, body, 0);
}

get_broadphase_contacts :: (using world: World) -> [..] Broadphase_Contact {
    get_broadphase_contacts_recursive :: (using tree: Octree, i: int, contacts: *[..] Broadphase_Contact) {
        if nodes.count == 0 return;

        using node := *nodes[i];

        for i: 0..bodies.count - 2 {
            for j: i + 1..bodies.count - 1 {
                if collision_aabb_aabb(get_aabb(bodies[i]), get_aabb(bodies[j])) && !(is_static(bodies[i]) && is_static(bodies[j])) {
                    array_add(contacts, .{ bodies[i], bodies[j] });
                }
            }
        }

        if !is_leaf {
            get_broadphase_contacts_recursive(tree, children[0], contacts);
            get_broadphase_contacts_recursive(tree, children[1], contacts);
            get_broadphase_contacts_recursive(tree, children[2], contacts);
            get_broadphase_contacts_recursive(tree, children[3], contacts);
            get_broadphase_contacts_recursive(tree, children[4], contacts);
            get_broadphase_contacts_recursive(tree, children[5], contacts);
            get_broadphase_contacts_recursive(tree, children[6], contacts);
            get_broadphase_contacts_recursive(tree, children[7], contacts);

            for bodies {
                get_broadphase_contacts_in_children_recursive(tree, children[0], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[1], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[2], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[3], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[4], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[5], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[6], it, contacts);
                get_broadphase_contacts_in_children_recursive(tree, children[7], it, contacts);
            }
        }
    }

    get_broadphase_contacts_in_children_recursive :: (using tree: Octree, i: int, body: *Body, contacts: *[..] Broadphase_Contact) {
        using node := *nodes[i];

        for other: bodies {
            if collision_aabb_aabb(get_aabb(body), get_aabb(other)) && !(is_static(body) && is_static(other)) {
                array_add(contacts, .{ body, other });
            }
        }

        if !is_leaf {
            get_broadphase_contacts_in_children_recursive(tree, children[0], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[1], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[2], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[3], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[4], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[5], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[6], body, contacts);
            get_broadphase_contacts_in_children_recursive(tree, children[7], body, contacts);
        }
    }

    quadtree: Octree;
    init(*quadtree, world,, temp);

    contacts: [..] Broadphase_Contact;
    get_broadphase_contacts_recursive(quadtree, 0, *contacts);

    return contacts;
}
