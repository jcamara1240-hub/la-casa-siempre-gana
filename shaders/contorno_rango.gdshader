shader_type canvas_item;
// El contorno de color de los enemigos raros y élite: el borde del dibujo (los píxeles opacos
// que tocan uno transparente) se pinta del color del rango y late. Solo lo llevan los que
// tienen rango, con un material compartido por rango: no cuesta nada por enemigo.

uniform vec4 color_rango : source_color = vec4(0.44, 0.76, 0.91, 1.0);
uniform float velocidad = 6.0;

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.0) {
		vec2 p = TEXTURE_PIXEL_SIZE;
		float vecinos = texture(TEXTURE, UV + vec2(p.x, 0.0)).a * texture(TEXTURE, UV - vec2(p.x, 0.0)).a
			* texture(TEXTURE, UV + vec2(0.0, p.y)).a * texture(TEXTURE, UV - vec2(0.0, p.y)).a;
		if (vecinos < 0.5) {
			float late = 0.75 + 0.25 * sin(TIME * velocidad);
			c.rgb = mix(c.rgb, color_rango.rgb * (0.8 + 0.6 * late), 0.9);
		}
	}
	COLOR = c;
}
