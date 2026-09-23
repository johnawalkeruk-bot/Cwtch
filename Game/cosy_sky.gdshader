shader_type sky;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.25);
uniform float daylight = 1.0;
uniform float cloud_cover = 0.15;
uniform float cycle_time = 0.0;
uniform float lightning = 0.0;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float clouds(vec3 p) {
 float value=0.0,weight=0.55;
 for(int i=0;i<5;i++){value+=noise(p)*weight;p=p*2.03+vec3(17.1,9.2,4.7);weight*=0.48;}
 return value;
}
void sky() {
 vec3 direction=normalize(EYEDIR),sun_dir=normalize(sun_direction);
 float elevation=direction.y;
 float twilight=(1.0-smoothstep(0.02,0.38,abs(sun_dir.y)))*smoothstep(-0.22,0.02,sun_dir.y);
 vec3 horizon=mix(vec3(0.72,0.76,0.76),vec3(0.92,0.58,0.43),twilight*0.75);
 vec3 zenith=mix(vec3(0.29,0.43,0.55),vec3(0.40,0.34,0.53),twilight*0.65);
 vec3 sky_color=mix(horizon,zenith,smoothstep(0.0,0.85,elevation));
 sky_color=mix(vec3(0.007,0.014,0.035)+sky_color*0.025,sky_color,daylight);
 // Smooth 3D density has no panorama seam or pinched poles.
 vec3 p=direction*vec3(5.5,3.0,5.5)+vec3(cycle_time*0.0018,0.0,cycle_time*0.0006);
 float density=clouds(p);
 float threshold=mix(0.62,0.23,cloud_cover);
 float cover=smoothstep(threshold,threshold+0.17,density)*smoothstep(-0.04,0.15,elevation);
 float wisps=smoothstep(0.57,0.73,clouds(p*1.8+vec3(40.0)))*0.24;
 cover=clamp(cover+wisps*smoothstep(0.0,0.3,elevation),0.0,1.0);
 // Fine, softly filtered star points with warmer and cooler individual colours.
 vec2 star_grid=vec2(atan(direction.z,direction.x)/6.2831853+0.5,acos(clamp(elevation,-1.0,1.0))/3.14159265)*vec2(800.0,400.0);
 vec2 cell=floor(star_grid);
 float seed=hash(vec3(mod(cell.x,800.0),cell.y,11.0));
 vec2 centre=vec2(hash(vec3(cell,23.0)),hash(vec3(cell,49.0)))*0.5+0.25;
 vec2 offset=fract(star_grid)-centre;
 float star=exp(-dot(offset,offset)*160.0)*step(0.995,seed);
 star*=0.8+0.2*sin(cycle_time*1.2+seed*900.0);
 vec3 star_color=mix(vec3(0.64,0.77,1.0),vec3(1.0,0.88,0.67),hash(vec3(cell,8.0)));
 sky_color+=star_color*star*pow(1.0-daylight,3.0)*smoothstep(0.02,0.3,elevation)*1.7;
 float sun=smoothstep(0.9993,0.9998,dot(direction,sun_dir));
 float halo=pow(max(dot(direction,sun_dir),0.0),60.0);
 float moon=smoothstep(0.9994,0.9998,dot(direction,-sun_dir));
 sky_color+=vec3(1.0,0.76,0.47)*(sun*1.3+halo*0.15)*daylight;
 sky_color+=vec3(0.53,0.65,0.85)*moon*(1.0-daylight);
 float lit=clamp(0.45+(density-clouds(p+sun_dir*0.18))*3.0,0.0,1.0);
 vec3 cloud_day=mix(vec3(0.39,0.46,0.49),vec3(0.89,0.89,0.82),lit);
 cloud_day=mix(cloud_day,vec3(0.81,0.58,0.50),twilight*0.32);
 vec3 cloud_color=mix(vec3(0.023,0.033,0.055),cloud_day,daylight);
 sky_color=mix(sky_color,cloud_color,cover*0.97);
 COLOR=mix(sky_color,vec3(0.80,0.87,0.98),clamp(lightning,0.0,1.0)*0.4);
}
