# example_map.py  —— 5×5 map

# run:cd Backend
# python test_cloud_mongodb.py;
# python test_local_mongodb.py;
# Then we can see the map in the cloud MongoDB;

example_map = [
    # ---------- LEVEL 1 ----------
    {
        "building": "Westfield Sydney1",
        "level": 1,
        "size": {"rows": 6, "cols": 6},
        "entrances": [
            {"entrance_id": "E1", "x": 0, "y": 3, "type": "car", "level": 1},
            {"entrance_id": "BE1", "x": 3, "y": 0, "type": "building", "level": 1},
        ],
        "exits": [{"exit_id": "X1", "x": 5, "y": 3, "level": 1}],
        "slots": [
            {"slot_id": "1A", "status": "available", "x": 2, "y": 2, "level": 1},
            {"slot_id": "1B", "status": "available", "x": 2, "y": 3, "level": 1},
            {"slot_id": "1C", "status": "available", "x": 3, "y": 2, "level": 1},
            {"slot_id": "1D", "status": "available", "x": 3, "y": 3, "level": 1},
        ],
        "corridors": [
            {
                "corridor_id": "C1_loop",
                "level": 1,
                "points": [
                    [1, 1],
                    [2, 1],
                    [3, 1],
                    [4, 1],  # bottom horizontal
                    [4, 2],
                    [4, 3],
                    [4, 4],  # right vertical
                    [3, 4],
                    [2, 4],
                    [1, 4],  # top horizontal
                    [1, 3],
                    [1, 2],
                    [1, 1],  # left vertical and back to start
                ],
                "direction": "both",
            },
            # Additional connecting corridors for proper navigation
            {
                "corridor_id": "C1_connect_vertical_1",
                "level": 1,
                "points": [[1, 3], [1, 4]],  # Connect lower left to upper left
                "direction": "both",
            },
            # Access to entrances and exits
            {
                "corridor_id": "C1_entrance_access",
                "level": 1,
                "points": [[0, 3], [1, 3]],
                "direction": "both",
            },
            {
                "corridor_id": "C1_exit_access",
                "level": 1,
                "points": [[4, 3], [5, 3]],
                "direction": "both",
            },
            {
                "corridor_id": "C1_building_access",
                "level": 1,
                "points": [[3, 1], [3, 0]],
                "direction": "both",
            },
            # Access to parking slots - ONE-WAY access paths (corridor -> slot)
            # Slot 1A access paths
            {
                "corridor_id": "C1_slot_1A_access_left",
                "level": 1,
                "points": [[1, 2], [2, 2]],
                "direction": "forward",
            },
            {
                "corridor_id": "C1_slot_1A_access_bottom",
                "level": 1,
                "points": [[2, 1], [2, 2]],
                "direction": "forward",
            },
            # Slot 1B access paths
            {
                "corridor_id": "C1_slot_1B_access_left",
                "level": 1,
                "points": [[1, 3], [2, 3]],
                "direction": "forward",
            },
            {
                "corridor_id": "C1_slot_1B_access_top",
                "level": 1,
                "points": [[2, 4], [2, 3]],
                "direction": "forward",
            },
            # Slot 1C access paths
            {
                "corridor_id": "C1_slot_1C_access_right",
                "level": 1,
                "points": [[4, 2], [3, 2]],
                "direction": "forward",
            },
            {
                "corridor_id": "C1_slot_1C_access_bottom",
                "level": 1,
                "points": [[3, 1], [3, 2]],
                "direction": "forward",
            },
            # Slot 1D access paths
            {
                "corridor_id": "C1_slot_1D_access_right",
                "level": 1,
                "points": [[4, 3], [3, 3]],
                "direction": "forward",
            },
            {
                "corridor_id": "C1_slot_1D_access_top",
                "level": 1,
                "points": [[3, 4], [3, 3]],
                "direction": "forward",
            },
        ],
        "walls": [
            {"wall_id": "W1", "level": 1, "points": [(0, 0), (5, 0)]},
            {"wall_id": "W2", "level": 1, "points": [(5, 0), (5, 5)]},
            {"wall_id": "W3", "level": 1, "points": [(5, 5), (0, 5)]},
            {"wall_id": "W4", "level": 1, "points": [(0, 5), (0, 0)]},
        ],
        "ramps": [
            {
                "ramp_id": "R1_up",
                "level": 1,
                "x": 1,
                "y": 0,
                "to_level": 2,
                "to_x": 1,
                "to_y": 1,
                "direction": "both",
            }
        ],
    },
    # ---------- LEVEL 2 ----------
    {
        "building": "Westfield Sydney1",
        "level": 2,
        "size": {"rows": 6, "cols": 6},
        "entrances": [
            {"entrance_id": "BE2", "x": 3, "y": 0, "type": "building", "level": 2}
        ],
        "exits": [{"exit_id": "X2", "x": 5, "y": 3, "level": 2}],
        "slots": [
            {"slot_id": "2A", "status": "available", "x": 2, "y": 2, "level": 2},
            {"slot_id": "2B", "status": "available", "x": 2, "y": 3, "level": 2},
            {"slot_id": "2C", "status": "available", "x": 3, "y": 2, "level": 2},
            {"slot_id": "2D", "status": "available", "x": 3, "y": 3, "level": 2},
        ],
        "corridors": [
            {
                "corridor_id": "C2_loop",
                "level": 2,
                "points": [
                    [1, 1],
                    [2, 1],
                    [3, 1],
                    [4, 1],  # bottom horizontal
                    [4, 2],
                    [4, 3],
                    [4, 4],  # right vertical
                    [3, 4],
                    [2, 4],
                    [1, 4],  # top horizontal
                    [1, 3],
                    [1, 2],
                    [1, 1],  # left vertical and back to start
                ],
                "direction": "both",
            },
            # Additional connecting corridors for proper navigation
            {
                "corridor_id": "C2_connect_vertical_1",
                "level": 2,
                "points": [[1, 3], [1, 4]],  # Connect lower left to upper left
                "direction": "both",
            },
            # Access to exits
            {
                "corridor_id": "C2_exit_access",
                "level": 2,
                "points": [[4, 3], [5, 3]],
                "direction": "both",
            },
            # Access to building entrance
            {
                "corridor_id": "C2_building_access",
                "level": 2,
                "points": [[3, 1], [3, 0]],
                "direction": "both",
            },
            # Access to ramp
            {
                "corridor_id": "C2_ramp_access",
                "level": 2,
                "points": [[1, 1], [1, 0]],
                "direction": "both",
            },
            # Access to parking slots - ONE-WAY access paths
            # Slot 2A access paths
            {
                "corridor_id": "C2_slot_2A_access_left",
                "level": 2,
                "points": [[1, 2], [2, 2]],
                "direction": "forward",
            },
            {
                "corridor_id": "C2_slot_2A_access_bottom",
                "level": 2,
                "points": [[2, 1], [2, 2]],
                "direction": "forward",
            },
            # Slot 2B access paths
            {
                "corridor_id": "C2_slot_2B_access_left",
                "level": 2,
                "points": [[1, 3], [2, 3]],
                "direction": "forward",
            },
            {
                "corridor_id": "C2_slot_2B_access_top",
                "level": 2,
                "points": [[2, 4], [2, 3]],
                "direction": "forward",
            },
            # Slot 2C access paths
            {
                "corridor_id": "C2_slot_2C_access_right",
                "level": 2,
                "points": [[4, 2], [3, 2]],
                "direction": "forward",
            },
            {
                "corridor_id": "C2_slot_2C_access_bottom",
                "level": 2,
                "points": [[3, 1], [3, 2]],
                "direction": "forward",
            },
            # Slot 2D access paths
            {
                "corridor_id": "C2_slot_2D_access_right",
                "level": 2,
                "points": [[4, 3], [3, 3]],
                "direction": "forward",
            },
            {
                "corridor_id": "C2_slot_2D_access_top",
                "level": 2,
                "points": [[3, 4], [3, 3]],
                "direction": "forward",
            },
        ],
        "walls": [
            {"wall_id": "W5", "level": 2, "points": [(0, 0), (5, 0)]},
            {"wall_id": "W6", "level": 2, "points": [(5, 0), (5, 5)]},
            {"wall_id": "W7", "level": 2, "points": [(5, 5), (0, 5)]},
            {"wall_id": "W8", "level": 2, "points": [(0, 5), (0, 0)]},
        ],
        "ramps": [
            {
                "ramp_id": "R1_down",
                "level": 2,
                "x": 1,
                "y": 0,
                "to_level": 1,
                "to_x": 1,
                "to_y": 1,
                "direction": "both",
            }
        ],
    },
]

# S : Available
# A : Allocated
# O : Occupied
# X : Exit
# E : Entrance
# C : Corridor
# W : Wall
# R : Ramp

# Level 1
# 5 | W W W W W W
# 4 | W C C C C W
# 3 | E C S S C X
# 2 | W C S S C W
# 1 | W C C C C W
# 0 | W R W E W W
# y/x 0 1 2 3 4 5


# Level 2
# 5 | W W W W W W
# 4 | W C C C C W
# 3 | W C A O C X
# 2 | W C O A C W
# 1 | W C C C C W
# 0 | W R W E W W
# y/x 0 1 2 3 4 5
