extends RefCounted
## Keep enough cool sky fill to navigate at night, with a warmer directional key.
static func update(environment: Environment, sun: DirectionalLight3D, elevation: float, daylight: float, clouds: float) -> void:
 sun.light_energy=maxf(0.0,elevation)*1.65*(1.0-clouds*0.62)
 sun.light_color=Color("ffc18b").lerp(Color("fff1dc"),smoothstep(0.0,0.5,elevation))
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("8398c6").lerp(Color("becbd3"),daylight)
 environment.ambient_light_sky_contribution=0.35
 environment.ambient_light_energy=lerpf(0.27,0.40,daylight)*(1.0-clouds*0.12)
