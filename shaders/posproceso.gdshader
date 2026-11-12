shader_type canvas_item;
render_mode unshaded;
// El posproceso de la zona de juego, en una sola pasada: viñeta y luz del centro, el borde
// que arde con la Fiebre, las líneas de velocidad, el tinte y la aberración del desatado y
// la viñeta roja que late al límite. Lo pinta un ColorRect por encima del mundo y por
// debajo del jugador, de las balas enemigas y de la interfaz. Vale para Compatibility y web.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float vineta = 0.38;      // lo que se oscurecen las esquinas
uniform float fiebre = 0.0;       // 0..1: cuánto arde el borde
uniform float lineas = 0.0;       // 0..1: líneas de velocidad
uniform float desatado = 0.0;     // 0..1: tinte y aberración
uniform float limite = 0.0;       // 0..1: viñeta roja (ya trae el latido)
uniform float aberracion = 1.5;   // en píxeles, en el borde
uniform float tiempo = 0.0;
uniform float golpe = 0.0;        // 0..1: te acaban de dar, la imagen se rompe en colores
uniform float cine = 0.0;         // píxeles de cada franja negra (momentos de cine)
uniform float brillo = 0.55;      // cuánto se desbordan las luces (resplandor)
uniform float alto_juego = 0.84444; // 304/360: la zona de juego dentro de la pantalla
uniform vec4 tinte : source_color = vec4(1.0, 0.9, 0.78, 1.0);

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = azar(i);
	float b = azar(i + vec2(1.0, 0.0));
	float c = azar(i + vec2(0.0, 1.0));
	float d = azar(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = floor(uv / SCREEN_PIXEL_SIZE);  // el píxel de pantalla: todo va en rejilla
	// -1..1 dentro de la zona de juego (la barra de cartas no cuenta).
	vec2 c = vec2(uv.x * 2.0 - 1.0, uv.y / alto_juego * 2.0 - 1.0);
	vec2 ca = c * vec2(1.0, 0.55);
	float r = length(ca);

	vec3 col;
	float rompe = desatado + golpe * 2.5;
	if (rompe > 0.001) {
		vec2 desvio = normalize(c + vec2(0.0001)) * SCREEN_PIXEL_SIZE * aberracion * rompe * smoothstep(0.15 - 0.15 * golpe, 1.0, r);
		col.r = texture(pantalla, uv + desvio).r;
		col.g = texture(pantalla, uv).g;
		col.b = texture(pantalla, uv - desvio).b;
	} else {
		col = texture(pantalla, uv).rgb;
	}

	// Resplandor: lo más claro de alrededor se desborda un poco. Ocho muestras en dos
	// anillos, en píxeles del juego, para que las luces y las explosiones brillen de verdad.
	if (brillo > 0.001) {
		vec2 p1 = vec2(1.0 / 640.0, 1.0 / 360.0);
		vec3 halo = vec3(0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(2.0, 2.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(-2.0, 2.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(2.0, -2.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(-2.0, -2.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(5.0, 0.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(-5.0, 0.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(0.0, 5.0)).rgb - 0.62, 0.0);
		halo += max(texture(pantalla, uv + p1 * vec2(0.0, -5.0)).rgb - 0.62, 0.0);
		col += halo * 0.3 * brillo;
	}
	// Un poco más de contraste: negros más hondos y luces más vivas.
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.1);

	// Luz del centro y bordes en penumbra.
	col *= 1.0 + 0.07 * (1.0 - smoothstep(0.0, 0.75, r));
	col *= 1.0 - vineta * smoothstep(0.45, 1.25, r);

	// Desatado: un poco más de contraste y un tinte caliente.
	if (desatado > 0.001) {
		vec3 calido = col * tinte.rgb * 1.1;
		calido = (calido - 0.5) * 1.08 + 0.5;
		col = mix(col, max(calido, vec3(0.0)), desatado * 0.3);
	}

	// Al límite: rojo que late desde las esquinas.
	if (limite > 0.001) {
		float m = smoothstep(0.42, 1.15, r) * limite;
		col = mix(col, vec3(0.55, 0.04, 0.10), m * 0.62);
	}

	// Fiebre: lenguas de fuego de pixel art que suben desde los lados y el suelo de la zona
	// de juego. Arriba (donde está el marcador) solo hay resplandor, sin llamas. Bajas y
	// medio transparentes: se notan de reojo sin tapar la sala ni los textos del muro.
	if (fiebre > 0.001) {
		vec2 zona = vec2(1.0 / SCREEN_PIXEL_SIZE.x, alto_juego / SCREEN_PIXEL_SIZE.y);
		float dx = min(px.x, zona.x - 1.0 - px.x);
		float dy = zona.y - 1.0 - px.y;                      // solo desde abajo
		float dmin = min(dx, min(dy, px.y));
		float d = floor(min(dx, dy) / 2.0) * 2.0;           // a bloques de 2 píxeles
		float a = floor((dx < dy ? px.y : px.x) / 2.0);       // por dónde va del borde
		float alto = mix(2.0, 11.0, fiebre);
		float h = alto * (0.3 + 0.7 * ruido(vec2(a * 0.23, tiempo * 3.5)));
		h += alto * 0.35 * ruido(vec2(a * 0.61 + 7.0, tiempo * 9.0));
		float lengua = ruido(vec2(a * 0.45, d * 0.22 - tiempo * 7.0));
		if (d < h && lengua > 0.3 + 0.5 * (d / max(h, 0.01))) {
			float q = d / max(h, 0.01);
			vec3 fuego = q < 0.3 ? vec3(0.97, 0.78, 0.29) : (q < 0.65 ? vec3(0.94, 0.51, 0.24) : vec3(0.84, 0.24, 0.31));
			col = mix(col, fuego, (0.6 - q * 0.35) * min(fiebre * 1.5, 1.0));
		}
		// Un resplandor naranja muy suave detrás de las llamas (también arriba).
		col += vec3(0.94, 0.45, 0.2) * (1.0 - smoothstep(0.0, 24.0, dmin)) * 0.16 * fiebre;
	}

	// Líneas de velocidad: rayas finas que convergen hacia el centro y parpadean.
	if (lineas > 0.001) {
		float ang = atan(ca.y, ca.x) * 0.15915 + 0.5;  // 0..1
		float n_rayas = 96.0;
		float cual = floor(ang * n_rayas);
		float paso = floor(tiempo * 14.0);
		float sale = azar(vec2(cual, paso));
		float fino = abs(fract(ang * n_rayas) - 0.5);
		float empieza = 0.62 + 0.4 * azar(vec2(cual * 1.7, paso + 3.0));
		float raya = step(0.72, sale) * step(fino, 0.09) * smoothstep(empieza, empieza + 0.25, r);
		col = mix(col, vec3(0.97, 0.93, 0.82), raya * lineas * 0.55);
	}

	// Te han dado: un fogonazo rojo que se va enseguida.
	col = mix(col, col * vec3(1.25, 0.7, 0.7), golpe * 0.5);

	// Franjas de cine, arriba y abajo de la zona de juego.
	if (cine > 0.01) {
		float y = uv.y * 360.0;
		float abajo = alto_juego * 360.0;
		if (y < cine || (y > abajo - cine && y <= abajo)) {
			col = vec3(0.02, 0.01, 0.04);
		}
	}

	COLOR = vec4(col, 1.0);
}
