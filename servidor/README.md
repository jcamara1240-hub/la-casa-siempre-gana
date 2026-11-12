# Tabla mundial del reto diario (Supabase)

Mientras no hagas estos pasos, el juego funciona exactamente igual que antes: sin
`online.cfg` no aparece nada online y no se hace ni una petición a internet.

Coste: el plan gratuito de Supabase basta de sobra (una fila por jugador y día).
Ojo: en el plan gratuito, un proyecto sin actividad durante una semana se **pausa**; se
reactiva desde el panel. Mientras esté pausado, el juego enseña "SIN CONEXIÓN" y guarda
las puntuaciones en cola (las del día se pierden si no se reactiva a tiempo).

## Pasos (unos 10 minutos)

1. **Crear el proyecto.** Entra en <https://supabase.com>, crea una cuenta y pulsa
   *New project*. Ponle un nombre (por ejemplo `la-casa-siempre-gana`), una contraseña
   de base de datos (guárdala, pero el juego no la usa) y una región cercana. Espera a
   que termine de crearse.

2. **Pegar el SQL.** En el menú de la izquierda: *SQL Editor* → *New query*. Abre
   `servidor/esquema.sql`, copia TODO su contenido, pégalo y pulsa *Run*. Debe decir
   *Success. No rows returned*. Se puede volver a ejecutar sin miedo si cambias algo.

3. **Copiar la URL y la clave anónima.** *Project Settings* (el engranaje) → *API*
   (en algunas versiones *Data API* / *API Keys*):
   - **Project URL**: algo como `https://abcdefghijkl.supabase.co`
   - **anon public** (clave anónima): un texto largo que empieza por `eyJ...`
     (o `sb_publishable_...` en los proyectos nuevos).

   La clave anónima es **pública** por diseño: va dentro del juego y cualquiera puede
   verla. No da acceso a las tablas (están cerradas); solo permite llamar a las seis
   funciones del esquema. **Nunca** pongas en el juego la clave `service_role` ni la
   contraseña de la base de datos.

4. **Crear el secreto de firma (recomendado).** Inventa un texto largo al azar, por
   ejemplo con `python3 -c "import secrets; print(secrets.token_hex(32))"`. En *SQL
   Editor* → *New query*, ejecuta (cambiando el texto):

   ```sql
   insert into privado.ajustes (clave, valor) values ('secreto_hmac', 'PEGA-AQUI-TU-SECRETO')
   on conflict (clave) do update set valor = excluded.valor;
   ```

5. **Crear `online.cfg`.** En la carpeta del proyecto de Godot (junto a
   `project.godot`), copia `online.ejemplo.cfg` como `online.cfg` y rellena `url`,
   `clave_anonima` y `secreto` (el mismo del paso 4). `online.cfg` está en `.gitignore`:
   **no lo subas nunca al repositorio**.

6. **Incluirlo al exportar.** Godot no mete archivos `.cfg` sueltos en el juego exportado
   si no se lo pides: en *Proyecto → Exportar*, en cada preset (Web, Windows, Android),
   pestaña *Recursos*, en *Filtros para exportar archivos que no son recursos* escribe
   `online.cfg`. (Para probar en tu ordenador sin exportar basta con el paso 5. También
   se lee `user://online.cfg`, por si quieres activarlo solo en tu máquina.)

7. **Probar.** Abre el juego → *Reto diario*: tiene que salir la pestaña *MUNDIAL* y
   pedirte un nombre. Juega el reto; al terminar, tu fila sale resaltada en la tabla.
   En Supabase, *Table Editor* → `puntuaciones` verás la fila.

## Nueva versión del juego

Cada versión puede cambiar la mazmorra del reto, así que el servidor solo acepta
envíos de las versiones activas (tabla `versiones`; el juego manda `Online.VERSION`,
en `scripts/online.gd`, ahora `1.7`). Al publicar una versión nueva:

```sql
insert into public.versiones (version) values ('1.8');
update public.versiones set activa = false where version = '1.7';  -- cuando ya no quieras la vieja
```

Y sube `VERSION` en `scripts/online.gd`. Si te olvidas, los envíos se rechazan con
el error `version` (el juego no se rompe; esa puntuación simplemente no sube).

## Qué hace cada pieza

- Tablas `jugadores`, `puntuaciones`, `versiones` (y `privado.ajustes` para el secreto).
  Todas con RLS activado y **sin políticas**: con la clave anónima no se pueden leer ni
  escribir directamente.
- Funciones (la única API): `registrar`, `poner_nombre`, `enviar_puntuacion`,
  `tabla_diaria`, `tabla_historica`, `borrar_cuenta`. El juego las llama con
  `POST <url>/rest/v1/rpc/<función>` con la cabecera `apikey` (y `Authorization: Bearer` si la
  clave es de las antiguas, `eyJ...`).
- Cuenta anónima: el juego genera un identificador al azar (guardado en
  `user://cuenta.cfg`) y el servidor le da un token. En la base solo se guarda la
  huella SHA-256 de ambos. Datos guardados: nombre público y puntuaciones (con piso,
  tiempo, bajas, monedas, golpes y versión). Nada más: ni correo, ni IP, ni dispositivo.
- `enviar_puntuacion` comprueba: token válido; versión activa; fecha de hoy en UTC (la
  de ayer se acepta hasta las 03:00 UTC, para partidas que cruzan la medianoche); una
  por jugador y día; números plausibles (piso 1-5, coherencia piso/victoria, al menos
  30 s por piso, topes de bajas/monedas/golpes); que los puntos salen exactamente de la
  fórmula; y la firma HMAC-SHA256 si hay secreto.
- Nombres: 3-16 caracteres `A-Z 0-9 Ñ -`, únicos, con un filtro básico de insultos
  ES/EN (la misma lista en `scripts/online.gd`). Un jugador sin nombre puede enviar,
  pero no aparece en la tabla hasta que lo elige.

## Cuánto protege esto contra trampas (léelo)

**Un cliente de juego nunca es a prueba de trampas.** El secreto HMAC viaja dentro
del juego exportado (en `online.cfg`, dentro del `.pck`/`.wasm`/`.apk`) y cualquiera con
un poco de paciencia puede extraerlo, o modificar el juego para que mande lo que quiera
con una firma válida. Lo que sí consigue:

- Frena el "curl con un JSON inventado" y la edición directa de la petición: sin el
  secreto la firma no cuadra.
- Los puntos tienen que salir de la fórmula y de números plausibles: no se puede mandar
  "999999" a pelo; el máximo real está acotado.
- Una puntuación por cuenta y día, y solo del día en curso.

Lo que **no** evita: alguien que saca el secreto, alguien que crea muchas cuentas
(no hay límite por IP en SQL puro), o alguien que juega con el juego modificado. Si un
día hace falta más, las opciones son: moderar a mano (borrar filas en *Table Editor*),
una Edge Function con límite de peticiones por IP, o guardar la repetición de la partida
(semilla + entradas) y verificarla en el servidor, que es lo único realmente fiable y
bastante más trabajo.

Para cambiar el secreto si se filtra: repite el paso 4 con uno nuevo, actualiza
`online.cfg` y publica una versión nueva (las versiones viejas, con el secreto viejo,
dejarán de poder enviar).

## Borrar una cuenta o moderar

- Desde el juego no hay botón todavía; la función `borrar_cuenta(p_token)` existe y
  `Online.borrar_cuenta()` la llama.
- A mano: *Table Editor* → `jugadores` → borrar la fila (sus puntuaciones se borran
  solas), o cambiarle el nombre.

## Diseño (no implementado): enlazar con Apple, Google o Steam

La cuenta anónima por dispositivo se pierde si se borra el juego. Para conservarla:

1. Tabla nueva `public.enlaces (jugador_id uuid references jugadores on delete cascade,
   proveedor text check (proveedor in ('apple','google','steam')), externo text,
   primary key (proveedor, externo))`.
2. **Apple / Google:** usar Supabase Auth con esos proveedores (Sign in with Apple,
   Google). El juego obtiene el token del sistema (plugin nativo en iOS/Android),
   lo canjea en Supabase Auth y recibe un JWT de usuario (`auth.uid()`).
3. **Steam:** una Edge Function que reciba el *session ticket* de Steamworks y lo valide
   con `ISteamUserAuth/AuthenticateUserTicket` (con la clave de editor, guardada como
   secreto de la función), devolviendo el SteamID.
4. RPC `enlazar(p_token, ...)` (llamada ya autenticada): si ese proveedor/ID no está
   enlazado, se enlaza a la cuenta del token. Si ya lo estaba a otra cuenta (otro
   dispositivo), se devuelve el token de esa cuenta y el juego lo adopta; las
   puntuaciones de la cuenta anónima se fusionan quedándose la mejor de cada día y la
   anónima se borra. El nombre que se queda es el de la cuenta enlazada.
5. Así se recupera la cuenta en un dispositivo nuevo: "Iniciar sesión" → enlazar → token.

## Pruebas sin Supabase

- `python3 tests/prueba_sql.py`: carga `esquema.sql` en un PostgreSQL local temporal
  (con los roles `anon`/`authenticated` de imitación) y prueba permisos, nombres,
  envíos, firma y tablas.
- `tests/servidor_falso.py` imita las rutas en memoria; lo usa `tests/prueba_online.gd`.

Nada de esto se ha probado contra un proyecto de Supabase real (PostgREST, su
configuración de CORS y sus claves nuevas). Haz el paso 7 antes de anunciarlo.
