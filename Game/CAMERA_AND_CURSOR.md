# Reference-inspired spirit and camera

The only visible player is the spirit ring. third_person_player.gd now contains
only the invisible grid-movement controller; it creates no meshes or children.

gliding_cursor.gd generates twelve extruded triangular arrowheads in a circle.
The tops are yellow and sides red. The geometry is unshaded to retain the vivid
reference colors, depth-tested, and raised about 10 cm above the ground.
It slowly rotates and bobs by 6 mm. The ring scales for tile or patch selection.

diorama_camera.gd retains perspective projection and the 1.5-metre camera height.
The horizontal offset is 1.4 metres: equal to the vertical difference between
the camera and the 10-cm-high ring center. This gives a 45-degree sightline.
Q/E orbits without changing these dimensions. FOV is 75 degrees.

The invisible controller eases between grid cells. The spirit follows its exact
position. Tools act on the selected cell after movement settles; patch actions
are clipped to the plot boundaries. The full source includes older generic
cursor APIs and first_person.gd, which is inactive.

Verified in Godot 4.6.2: no humanoid meshes; twelve red/yellow arrowheads;
perspective camera with the requested height and angle through an orbit;
gliding, tool actions, patch resizing, pause, and music. The rendered ring was
visually compared with the supplied screenshot.
