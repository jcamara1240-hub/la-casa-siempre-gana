-- =====================================================================================
-- La Casa Siempre Gana: tabla mundial del reto diario (Supabase / PostgreSQL 15+).
--
-- Se pega ENTERO en Supabase -> SQL Editor -> New query -> Run. Se puede volver a
-- ejecutar sin romper nada (todo es "if not exists" / "create or replace").
--
-- Cómo está montado:
--   * Las tablas tienen RLS activado y NINGUNA política: con la clave anónima nadie
--     puede leerlas ni escribirlas directamente.
--   * Todo pasa por funciones (RPC) "security definer" que validan lo que entra.
--     El juego las llama con POST https://<proyecto>.supabase.co/rest/v1/rpc/<función>.
--   * El secreto para firmar los envíos vive en el esquema "privado", que la API no
--     expone. Se pone a mano (ver README.md, paso 4). Nunca va en el repositorio.
-- =====================================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ esquema privado
create schema if not exists privado;
revoke all on schema privado from public;

create table if not exists privado.ajustes (
	clave text primary key,
	valor text not null
);
revoke all on privado.ajustes from public;

-- ------------------------------------------------------------------ tablas
-- Versiones del juego que pueden enviar puntuaciones. Al publicar una versión que cambie
-- el reto, se añade la nueva y se desactiva la vieja (README.md, "Nueva versión").
create table if not exists public.versiones (
	version text primary key,
	activa boolean not null default true,
	creada timestamptz not null default now()
);
insert into public.versiones (version) values ('1.7') on conflict do nothing;

-- Una cuenta anónima por dispositivo. No se guarda ni el identificador del dispositivo
-- ni el token: solo su huella (sha256), así una filtración de la base no da acceso.
create table if not exists public.jugadores (
	id uuid primary key default gen_random_uuid(),
	dispositivo_hash text not null unique,
	token_hash text not null unique,
	nombre text unique,
	creado timestamptz not null default now(),
	constraint nombre_formato check (nombre is null or nombre ~ '^[A-Z0-9Ñ-]{3,16}$')
);

create table if not exists public.puntuaciones (
	id bigint generated always as identity primary key,
	jugador_id uuid not null references public.jugadores (id) on delete cascade,
	fecha date not null,
	modo text not null check (modo in ('diario')),
	puntos integer not null check (puntos between 0 and 100000),
	piso integer not null check (piso between 1 and 5),
	pisos integer not null check (pisos between 0 and 5),
	gano boolean not null,
	tiempo_seg integer not null check (tiempo_seg between 0 and 21600),
	bajas integer not null check (bajas >= 0),
	monedas integer not null check (monedas >= 0),
	golpes integer not null check (golpes >= 0),
	version text not null,
	creada timestamptz not null default now(),
	unique (jugador_id, fecha, modo)  -- una por jugador, día y modo
);
create index if not exists puntuaciones_tabla on public.puntuaciones (fecha, modo, puntos desc, tiempo_seg asc);
create index if not exists puntuaciones_jugador on public.puntuaciones (jugador_id);

-- RLS sin políticas = cerrado a cal y canto para anon y authenticated.
alter table public.versiones enable row level security;
alter table public.jugadores enable row level security;
alter table public.puntuaciones enable row level security;
revoke all on public.versiones, public.jugadores, public.puntuaciones from anon, authenticated;

-- ------------------------------------------------------------------ ayudantes privados
create or replace function privado.huella(texto text) returns text
language sql immutable
set search_path = extensions, pg_temp
as $$ select encode(extensions.digest(texto, 'sha256'), 'hex') $$;

create or replace function privado.jugador_de(p_token text) returns uuid
language sql stable
set search_path = public, pg_temp
as $$
	select id from public.jugadores
	where p_token is not null and p_token <> '' and token_hash = privado.huella(p_token)
$$;

-- Filtro básico de insultos (ES/EN). La misma lista está en scripts/online.gd.
-- Se compara en minúsculas, sin guiones y deshaciendo el "leet" (0->o, 1->i, 3->e...).
create or replace function privado.nombre_feo(p_nombre text) returns boolean
language sql immutable
as $$
	select exists (
		select 1
		from unnest(array['puta', 'puto', 'mierda', 'cabron', 'gilipollas', 'maricon', 'marica', 'polla',
			'zorra', 'joder', 'follar', 'subnormal', 'retrasado', 'pendejo', 'culero', 'verga', 'chinga', 'nazi',
			'hitler', 'fuck', 'shit', 'bitch', 'cunt', 'nigger', 'nigga', 'faggot', 'whore', 'slut', 'asshole',
			'retard', 'rape', 'penis', 'admin']) as palabra
		where translate(lower(p_nombre), 'ñÑ0134578-', 'nnoieastb') like '%' || palabra || '%'
	)
$$;

-- La fórmula de puntos. Tiene que ser IDÉNTICA a Juego.calcular_puntos (scripts/juego.gd).
create or replace function privado.calcular_puntos(p_pisos int, p_gano boolean, p_tiempo int,
		p_bajas int, p_monedas int, p_golpes int) returns integer
language sql immutable
as $$
	select greatest(0,
		p_pisos * 1000 + p_bajas * 2 + p_monedas * 1 - p_golpes * 100
		+ case when p_gano then 5000 + greatest(1500 - p_tiempo, 0) * 3 else 0 end)
$$;

revoke all on all functions in schema privado from public;

-- ------------------------------------------------------------------ API (RPC)
-- Cuenta anónima. El dispositivo manda un identificador al azar que solo él conoce.
-- Si ya existía (p. ej. se perdió la respuesta), se le da un token nuevo.
create or replace function public.registrar(p_dispositivo text) returns json
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
	v_token text := encode(extensions.gen_random_bytes(32), 'hex');
	v_id uuid;
	v_nombre text;
begin
	if p_dispositivo is null or length(p_dispositivo) not between 16 and 128 then
		return json_build_object('ok', false, 'error', 'invalido');
	end if;
	insert into public.jugadores (dispositivo_hash, token_hash)
	values (privado.huella(p_dispositivo), privado.huella(v_token))
	on conflict (dispositivo_hash) do update set token_hash = excluded.token_hash
	returning id, nombre into v_id, v_nombre;
	return json_build_object('ok', true, 'jugador', v_id, 'token', v_token, 'nombre', v_nombre);
end
$$;

create or replace function public.poner_nombre(p_token text, p_nombre text) returns json
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
	v_id uuid := privado.jugador_de(p_token);
	v_nombre text := upper(btrim(coalesce(p_nombre, '')));
begin
	if v_id is null then
		return json_build_object('ok', false, 'error', 'token');
	end if;
	if char_length(v_nombre) < 3 then
		return json_build_object('ok', false, 'error', 'nombre_corto');
	end if;
	if char_length(v_nombre) > 16 then
		return json_build_object('ok', false, 'error', 'nombre_largo');
	end if;
	if v_nombre !~ '^[A-Z0-9Ñ-]+$' then
		return json_build_object('ok', false, 'error', 'nombre_invalido');
	end if;
	if privado.nombre_feo(v_nombre) then
		return json_build_object('ok', false, 'error', 'nombre_feo');
	end if;
	begin
		update public.jugadores set nombre = v_nombre where id = v_id;
	exception when unique_violation then
		return json_build_object('ok', false, 'error', 'nombre_ocupado');
	end;
	return json_build_object('ok', true, 'nombre', v_nombre);
end
$$;

-- Envío de una puntuación del reto diario. Comprueba:
--   token válido, versión activa, fecha de hoy (UTC; la de ayer solo hasta las 03:00 UTC,
--   para las partidas que cruzan la medianoche), números plausibles, que los puntos
--   salen de la fórmula y, si hay secreto configurado, la firma HMAC-SHA256.
-- Una por jugador y día: si ya había una, no se toca y responde "repetido".
create or replace function public.enviar_puntuacion(
		p_token text, p_fecha date, p_modo text, p_puntos int, p_piso int, p_pisos int, p_gano boolean,
		p_tiempo int, p_bajas int, p_monedas int, p_golpes int, p_version text, p_firma text default '')
returns json
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
	v_id uuid := privado.jugador_de(p_token);
	v_ahora timestamp := now() at time zone 'utc';
	v_hoy date := (now() at time zone 'utc')::date;
	v_secreto text;
	v_texto text;
begin
	if v_id is null then
		return json_build_object('ok', false, 'error', 'token');
	end if;
	if not exists (select 1 from public.versiones where version = p_version and activa) then
		return json_build_object('ok', false, 'error', 'version');
	end if;
	if p_modo is distinct from 'diario' or p_fecha is null then
		return json_build_object('ok', false, 'error', 'invalido');
	end if;
	if not (p_fecha = v_hoy or (p_fecha = v_hoy - 1 and v_ahora < v_hoy + interval '3 hours')) then
		return json_build_object('ok', false, 'error', 'fuera_de_plazo');
	end if;
	if p_piso is null or p_pisos is null or p_gano is null or p_tiempo is null or p_bajas is null
			or p_monedas is null or p_golpes is null or p_puntos is null
			or p_piso not between 1 and 5
			or p_pisos <> (case when p_gano then 5 else p_piso - 1 end)
			or (p_gano and p_piso <> 5)
			or p_tiempo not between 30 * p_pisos and 21600
			or p_bajas not between 0 and 1500 * (p_pisos + 1)
			or p_monedas not between 0 and 2000 * (p_pisos + 1)
			or p_golpes not between 0 and 200 then
		return json_build_object('ok', false, 'error', 'implausible');
	end if;
	if p_puntos <> privado.calcular_puntos(p_pisos, p_gano, p_tiempo, p_bajas, p_monedas, p_golpes) then
		return json_build_object('ok', false, 'error', 'puntos');
	end if;
	select valor into v_secreto from privado.ajustes where clave = 'secreto_hmac';
	if coalesce(v_secreto, '') <> '' then
		-- Mismo texto que Online.texto_firma (scripts/online.gd).
		v_texto := concat_ws('|', p_token, to_char(p_fecha, 'YYYY-MM-DD'), p_modo, p_puntos, p_piso, p_pisos,
			case when p_gano then 1 else 0 end, p_tiempo, p_bajas, p_monedas, p_golpes, p_version);
		if coalesce(p_firma, '') <> encode(extensions.hmac(v_texto, v_secreto, 'sha256'), 'hex') then
			return json_build_object('ok', false, 'error', 'firma');
		end if;
	end if;
	insert into public.puntuaciones (jugador_id, fecha, modo, puntos, piso, pisos, gano, tiempo_seg, bajas,
		monedas, golpes, version)
	values (v_id, p_fecha, p_modo, p_puntos, p_piso, p_pisos, p_gano, p_tiempo, p_bajas, p_monedas, p_golpes,
		p_version)
	on conflict (jugador_id, fecha, modo) do nothing;
	if not found then
		return json_build_object('ok', true, 'repetido', true);
	end if;
	return json_build_object('ok', true);
end
$$;

-- Los mejores de un día (solo jugadores con nombre) y tu fila, aunque estés más abajo.
-- Empates: mismo puesto con los mismos puntos y tiempo.
create or replace function public.tabla_diaria(p_fecha date, p_modo text default 'diario',
		p_token text default '', p_limite int default 50) returns json
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
declare
	v_id uuid := privado.jugador_de(p_token);
	v_resultado json;
begin
	with tabla as (
		select p.jugador_id, j.nombre, p.puntos, p.piso, p.tiempo_seg, p.creada,
			rank() over (order by p.puntos desc, p.tiempo_seg asc) as pos
		from public.puntuaciones p
		join public.jugadores j on j.id = p.jugador_id
		where p.fecha = p_fecha and p.modo = p_modo and j.nombre is not null
	)
	select json_build_object(
		'ok', true,
		'fecha', to_char(p_fecha, 'YYYY-MM-DD'),
		'total', (select count(*) from tabla),
		'top', coalesce((
			select json_agg(json_build_object('pos', t.pos, 'nombre', t.nombre, 'puntos', t.puntos, 'piso', t.piso,
				'tiempo', t.tiempo_seg, 'yo', coalesce(t.jugador_id = v_id, false)) order by t.pos, t.creada)
			from (select * from tabla order by pos, creada limit least(greatest(coalesce(p_limite, 50), 1), 100)) t
		), '[]'::json),
		'yo', (
			select json_build_object('pos', t.pos, 'nombre', t.nombre, 'puntos', t.puntos, 'piso', t.piso,
				'tiempo', t.tiempo_seg, 'yo', true)
			from tabla t where t.jugador_id = v_id
		)
	) into v_resultado;
	return v_resultado;
end
$$;

-- Histórico: la mejor marca de un solo día de cada jugador, de siempre.
create or replace function public.tabla_historica(p_token text default '', p_limite int default 50) returns json
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
declare
	v_id uuid := privado.jugador_de(p_token);
	v_resultado json;
begin
	with mejores as (
		select distinct on (p.jugador_id) p.jugador_id, j.nombre, p.puntos, p.piso, p.tiempo_seg, p.fecha, p.creada
		from public.puntuaciones p
		join public.jugadores j on j.id = p.jugador_id
		where p.modo = 'diario' and j.nombre is not null
		order by p.jugador_id, p.puntos desc, p.tiempo_seg asc, p.creada asc
	), tabla as (
		select m.*, rank() over (order by m.puntos desc, m.tiempo_seg asc) as pos from mejores m
	)
	select json_build_object(
		'ok', true,
		'total', (select count(*) from tabla),
		'top', coalesce((
			select json_agg(json_build_object('pos', t.pos, 'nombre', t.nombre, 'puntos', t.puntos, 'piso', t.piso,
				'tiempo', t.tiempo_seg, 'fecha', to_char(t.fecha, 'YYYY-MM-DD'), 'yo', coalesce(t.jugador_id = v_id, false))
				order by t.pos, t.creada)
			from (select * from tabla order by pos, creada limit least(greatest(coalesce(p_limite, 50), 1), 100)) t
		), '[]'::json),
		'yo', (
			select json_build_object('pos', t.pos, 'nombre', t.nombre, 'puntos', t.puntos, 'piso', t.piso,
				'tiempo', t.tiempo_seg, 'fecha', to_char(t.fecha, 'YYYY-MM-DD'), 'yo', true)
			from tabla t where t.jugador_id = v_id
		)
	) into v_resultado;
	return v_resultado;
end
$$;

-- Borra la cuenta y todas sus puntuaciones (derecho de supresión).
create or replace function public.borrar_cuenta(p_token text) returns json
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
	delete from public.jugadores where id = privado.jugador_de(p_token);
	return json_build_object('ok', true);
end
$$;

-- ------------------------------------------------------------------ permisos
-- Solo estas seis funciones son la API pública. Nada más se puede tocar con la clave anónima.
revoke execute on function public.registrar(text), public.poner_nombre(text, text),
	public.enviar_puntuacion(text, date, text, int, int, int, boolean, int, int, int, int, text, text),
	public.tabla_diaria(date, text, text, int), public.tabla_historica(text, int),
	public.borrar_cuenta(text) from public;
grant execute on function public.registrar(text), public.poner_nombre(text, text),
	public.enviar_puntuacion(text, date, text, int, int, int, boolean, int, int, int, int, text, text),
	public.tabla_diaria(date, text, text, int), public.tabla_historica(text, int),
	public.borrar_cuenta(text) to anon, authenticated;
