-- SYRCAM ERP/CRM Corporativo - Esquema Relacional Supabase/PostgreSQL
-- Contexto: República Dominicana (RD$ base, soporte USD, NCF/e-NCF, ITBIS, TSS, INFOTEP)

create extension if not exists pgcrypto;

create type public.syrcam_moneda as enum ('DOP', 'USD', 'EUR');
create type public.syrcam_semaforo as enum ('VERDE', 'AMARILLO', 'ROJO');
create type public.syrcam_estado_doc as enum ('BORRADOR', 'VIGENTE', 'OBSOLETO');

create table if not exists public.usuarios (
    id uuid primary key default gen_random_uuid(),
    email text not null unique,
    nombre_completo text not null,
    rol text not null check (rol in ('GERENCIA','VENTAS','OPERACIONES','CONTABILIDAD','CALIDAD','ADMIN')),
    activo boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.clientes (
    id uuid primary key default gen_random_uuid(),
    cliente_id text not null unique,
    razon_social text not null,
    nombre_comercial text,
    rnc text not null unique,
    telefono text,
    email text,
    direccion text,
    tipo_cliente text,
    estado text not null default 'ACTIVO',
    semaforo public.syrcam_semaforo not null default 'VERDE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.solicitudes (
    id uuid primary key default gen_random_uuid(),
    solicitud_id text not null unique,
    cliente_id uuid not null references public.clientes(id),
    ticket_ref text,
    fecha_solicitud timestamptz not null,
    tipo_solicitud text not null,
    prioridad text not null,
    descripcion text not null,
    estado_ticket text not null,
    asignado_a uuid references public.usuarios(id),
    fecha_programada date,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.cotizaciones (
    id uuid primary key default gen_random_uuid(),
    cotizacion_id text not null unique,
    solicitud_id uuid references public.solicitudes(id),
    cliente_id uuid not null references public.clientes(id),
    fecha_cotizacion date not null,
    vigencia_hasta date,
    monto_ofertado numeric(18,2) not null,
    moneda_origen public.syrcam_moneda not null default 'DOP',
    tasa_cambio numeric(18,6) not null default 1,
    monto_ofertado_rd numeric(18,2) generated always as (
        case when moneda_origen = 'DOP' then monto_ofertado else monto_ofertado * tasa_cambio end
    ) stored,
    estado_oferta text not null,
    probabilidad_cierre numeric(5,2),
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.ventas (
    id uuid primary key default gen_random_uuid(),
    venta_id text not null unique,
    cotizacion_id uuid references public.cotizaciones(id),
    cliente_id uuid not null references public.clientes(id),
    fecha_venta date not null,
    fecha_factura date,
    ncf text,
    encf text,
    rnc_relacionado text,
    monto_base numeric(18,2) not null,
    itbis numeric(18,2) not null default 0,
    retenciones numeric(18,2) not null default 0,
    monto_total numeric(18,2) not null,
    moneda_origen public.syrcam_moneda not null default 'DOP',
    tasa_cambio numeric(18,6) not null default 1,
    monto_total_rd numeric(18,2) generated always as (
        case when moneda_origen = 'DOP' then monto_total else monto_total * tasa_cambio end
    ) stored,
    estado_contrato text not null,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.contratos (
    id uuid primary key default gen_random_uuid(),
    contrato_id text not null unique,
    venta_id uuid not null references public.ventas(id),
    cliente_id uuid not null references public.clientes(id),
    fecha_contrato date not null,
    alcance text,
    estado text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.proyectos (
    id uuid primary key default gen_random_uuid(),
    proyecto_id text not null unique,
    contrato_id uuid references public.contratos(id),
    venta_id uuid references public.ventas(id),
    cliente_id uuid not null references public.clientes(id),
    nombre_proyecto text not null,
    linea_negocio text,
    fecha_inicio date,
    fecha_cierre date,
    presupuesto_base_rd numeric(18,2) not null default 0,
    estado text not null,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.costos_proyecto (
    id uuid primary key default gen_random_uuid(),
    proyecto_id uuid not null references public.proyectos(id),
    costo_id text not null unique,
    fecha_costo date not null,
    tipo_costo text not null,
    costo_directo_rd numeric(18,2) not null default 0,
    costo_indirecto_rd numeric(18,2) not null default 0,
    gasto_admin_rd numeric(18,2) not null default 0,
    provisiones_rd numeric(18,2) not null default 0,
    monto_total_rd numeric(18,2) not null,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.costos_tiempo (
    id uuid primary key default gen_random_uuid(),
    proyecto_id uuid not null references public.proyectos(id),
    fecha_labor date not null,
    horas_regulares numeric(10,2) not null default 0,
    horas_extras numeric(10,2) not null default 0,
    tarifa_hora_rd numeric(18,2) not null,
    costo_jornada_rd numeric(18,2) not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.costos_fijos (
    id uuid primary key default gen_random_uuid(),
    periodo_fiscal date not null,
    categoria text not null,
    monto_presupuestado_rd numeric(18,2) not null,
    monto_real_rd numeric(18,2) not null,
    desviacion_rd numeric(18,2) generated always as (monto_real_rd - monto_presupuestado_rd) stored,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.costos_variables (
    id uuid primary key default gen_random_uuid(),
    proyecto_id uuid references public.proyectos(id),
    fecha_registro date not null,
    concepto text not null,
    costo_total_variable_rd numeric(18,2) not null,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.inventario_items (
    id uuid primary key default gen_random_uuid(),
    item_id text not null unique,
    sku text not null unique,
    descripcion text not null,
    categoria text not null,
    unidad text not null,
    stock_actual numeric(18,2) not null default 0,
    punto_reorden numeric(18,2) not null default 0,
    costo_unitario_rd numeric(18,2) not null default 0,
    valor_total_rd numeric(18,2) generated always as (stock_actual * costo_unitario_rd) stored,
    semaforo public.syrcam_semaforo not null default 'VERDE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.inventario_movimientos (
    id uuid primary key default gen_random_uuid(),
    item_id uuid not null references public.inventario_items(id),
    proyecto_id uuid references public.proyectos(id),
    fecha_movimiento timestamptz not null,
    tipo_movimiento text not null check (tipo_movimiento in ('ENTRADA', 'SALIDA', 'AJUSTE')),
    cantidad numeric(18,2) not null,
    costo_unitario_rd numeric(18,2) not null,
    documento_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.finanzas_movimientos (
    id uuid primary key default gen_random_uuid(),
    movimiento_id text not null unique,
    cliente_id uuid references public.clientes(id),
    venta_id uuid references public.ventas(id),
    contrato_id uuid references public.contratos(id),
    proyecto_id uuid references public.proyectos(id),
    fecha_movimiento date not null,
    tipo_movimiento text not null check (tipo_movimiento in ('INGRESO', 'EGRESO', 'TRANSFERENCIA')),
    categoria_flujo text,
    monto numeric(18,2) not null,
    moneda_origen public.syrcam_moneda not null default 'DOP',
    tasa_cambio numeric(18,6) not null default 1,
    monto_rd numeric(18,2) generated always as (
        case when moneda_origen = 'DOP' then monto else monto * tasa_cambio end
    ) stored,
    ncf text,
    rnc_relacionado text,
    estado_conciliacion text not null,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.contabilidad_asientos (
    id uuid primary key default gen_random_uuid(),
    asiento_id text not null unique,
    fecha_asiento date not null,
    cuenta_mayor text not null,
    cuenta_auxiliar text,
    tipo_movimiento text not null check (tipo_movimiento in ('DEBE','HABER')),
    monto_rd numeric(18,2) not null,
    documento_id text,
    movimiento_finanzas_id uuid references public.finanzas_movimientos(id),
    proyecto_id uuid references public.proyectos(id),
    periodo_fiscal date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.impuestos_obligaciones (
    id uuid primary key default gen_random_uuid(),
    obligacion_id text not null unique,
    periodo_fiscal date not null,
    tipo_impuesto text not null,
    base_imponible_rd numeric(18,2) not null default 0,
    deducciones_rd numeric(18,2) not null default 0,
    monto_pagar_rd numeric(18,2) not null,
    fecha_limite date not null,
    fecha_pago date,
    estado text not null,
    tss_infotep boolean not null default false,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.incidencias (
    id uuid primary key default gen_random_uuid(),
    incidencia_id text not null unique,
    proyecto_id uuid references public.proyectos(id),
    fecha_incidente timestamptz not null,
    clasificacion text not null,
    costo_impacto_rd numeric(18,2) not null default 0,
    estado text not null,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.calidad_servicio (
    id uuid primary key default gen_random_uuid(),
    calidad_id text not null unique,
    proyecto_id uuid references public.proyectos(id),
    fecha_inspeccion date not null,
    resultado text not null,
    retrabajo boolean not null default false,
    costo_no_calidad_rd numeric(18,2) not null default 0,
    semaforo public.syrcam_semaforo not null default 'VERDE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.mejora_continua (
    id uuid primary key default gen_random_uuid(),
    mejora_id text not null unique,
    fecha_apertura date not null,
    origen text not null,
    plan_accion text not null,
    fecha_cierre_proyectada date,
    estado text not null,
    inversion_rd numeric(18,2) not null default 0,
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.reuniones_seguimiento (
    id uuid primary key default gen_random_uuid(),
    reunion_id text not null unique,
    fecha_reunion timestamptz not null,
    tipo_reunion text not null,
    acuerdos text,
    compromisos text,
    documento_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.documentos_calidad (
    id uuid primary key default gen_random_uuid(),
    documento_id text not null unique,
    codigo_documento text not null unique,
    tipo_documento text not null,
    titulo text not null,
    version text not null,
    estado public.syrcam_estado_doc not null default 'BORRADOR',
    fecha_publicacion date,
    url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.auditorias (
    id uuid primary key default gen_random_uuid(),
    auditoria_id text not null unique,
    fecha_inicio date not null,
    fecha_fin date,
    tipo_auditoria text not null,
    area_auditada text,
    nivel_cumplimiento numeric(5,2),
    estado_auditoria text not null,
    documento_id uuid references public.documentos_calidad(id),
    semaforo public.syrcam_semaforo not null default 'AMARILLO',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Vistas de indicadores para dashboard ejecutivo
create or replace view public.vw_kpi_finanzas_mensual as
select
    date_trunc('month', fecha_movimiento)::date as periodo,
    sum(case when tipo_movimiento = 'INGRESO' then monto_rd else 0 end) as ingresos_rd,
    sum(case when tipo_movimiento = 'EGRESO' then monto_rd else 0 end) as egresos_rd,
    sum(case when tipo_movimiento = 'INGRESO' then monto_rd else -monto_rd end) as flujo_neto_rd
from public.finanzas_movimientos
group by 1;

create or replace view public.vw_kpi_proyectos_rentabilidad as
select
    p.id as proyecto_uuid,
    p.proyecto_id,
    p.nombre_proyecto,
    coalesce(sum(v.monto_total_rd), 0) as ingresos_rd,
    coalesce(sum(c.monto_total_rd), 0) as costos_rd,
    coalesce(sum(v.monto_total_rd), 0) - coalesce(sum(c.monto_total_rd), 0) as utilidad_neta_rd,
    case
        when coalesce(sum(v.monto_total_rd), 0) = 0 then 0
        else round(((coalesce(sum(v.monto_total_rd), 0) - coalesce(sum(c.monto_total_rd), 0)) / sum(v.monto_total_rd)) * 100, 2)
    end as margen_neto_pct
from public.proyectos p
left join public.ventas v on v.id = p.venta_id
left join public.costos_proyecto c on c.proyecto_id = p.id
group by p.id, p.proyecto_id, p.nombre_proyecto;

create or replace view public.vw_kpi_cumplimiento_fiscal as
select
    periodo_fiscal,
    count(*) as obligaciones_totales,
    count(*) filter (where estado ilike '%pagado%') as obligaciones_pagadas,
    count(*) filter (where estado not ilike '%pagado%') as obligaciones_pendientes,
    sum(monto_pagar_rd) filter (where estado not ilike '%pagado%') as monto_pendiente_rd
from public.impuestos_obligaciones
group by periodo_fiscal;

create index if not exists idx_solicitudes_cliente on public.solicitudes(cliente_id);
create index if not exists idx_cotizaciones_cliente on public.cotizaciones(cliente_id);
create index if not exists idx_ventas_cliente on public.ventas(cliente_id);
create index if not exists idx_proyectos_cliente on public.proyectos(cliente_id);
create index if not exists idx_costos_proyecto on public.costos_proyecto(proyecto_id);
create index if not exists idx_finanzas_proyecto on public.finanzas_movimientos(proyecto_id);
create index if not exists idx_impuestos_periodo on public.impuestos_obligaciones(periodo_fiscal);

-- Trigger genérico de mantenimiento para updated_at
create or replace function public.syrcam_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array[
    'usuarios','clientes','solicitudes','cotizaciones','ventas','contratos','proyectos',
    'costos_proyecto','costos_tiempo','costos_fijos','costos_variables',
    'inventario_items','inventario_movimientos','finanzas_movimientos','contabilidad_asientos',
    'impuestos_obligaciones','incidencias','calidad_servicio','mejora_continua',
    'reuniones_seguimiento','documentos_calidad','auditorias'
  ]
  loop
    execute format('drop trigger if exists trg_%I_touch_updated_at on public.%I;', t, t);
    execute format('create trigger trg_%I_touch_updated_at before update on public.%I for each row execute function public.syrcam_touch_updated_at();', t, t);
  end loop;
end $$;
