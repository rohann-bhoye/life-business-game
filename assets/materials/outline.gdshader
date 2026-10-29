shader_type spatial;
// Inverted-hull outline for anime looks: drawn as a next pass, pushed out along the
// normals and showing only its back faces, in one flat dark navy.
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.106, 0.106, 0.184, 1.0);
uniform float width = 0.02;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
