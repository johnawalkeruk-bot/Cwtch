# Crypto local asset conversion

Source: the supplied local Destroy All Humans! 2 Reprobed installation.
Model: `DH2/Content/Meshes/Characters/crypto.uasset`.
Animations: `C_unarmed_idle_01` (Idle) and `c_unarmed_walk_F_ADD` (Walk).
The converter resolves the additive walk against its reference pose before export.

Converted with CUE4Parse game-specific UE5.6 support, UEFormat and Blender 5.1.
130-bone skeleton; horizontal trajectory removed for collision-driven movement.
Textures resized to 1024px, body/jetpack normal-map green channels converted for glTF.
Eye material simplified; source runtime mood render target is not transferred.
GLB uses four normalized skin influences per vertex. Material and animation checks
were performed in Blender and Godot. Original installation files are unchanged.

Temporary extraction tools and the Blender working file are in ignored
`.local/crypto-tools/`; they are not part of the game runtime.
