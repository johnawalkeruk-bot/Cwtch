shader_type sky;
uniform vec3 sun_direction = vec3(0.5,0.5,0.0);
uniform float daylight = 1.0;
uniform float cloud_cover = 0.15;
uniform float cycle_time = 0.0;
uniform float lightning = 0.0;
void sky() {
 float sunset=(1.0-smoothstep(0.0,0.32,abs(sun_direction.y)))*daylight;
 vec3 paper=mix(vec3(0.975,0.983,0.98),vec3(0.97,0.90,0.81),sunset*0.42);
 paper=mix(paper,vec3(0.78,0.84,0.85),cloud_cover*0.25);
 vec3 night=mix(vec3(0.025,0.045,0.073),vec3(0.065,0.105,0.15),clamp(EYEDIR.y+0.5,0.0,1.0));
 COLOR=mix(mix(night,paper,daylight),vec3(0.85,0.91,0.98),lightning*0.35);
}
