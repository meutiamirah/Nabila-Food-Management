create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  photo_base64 text,
  updated_at timestamptz not null default now()
);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  category text not null,
  quantity numeric not null default 0 check (quantity >= 0),
  capacity numeric not null default 0 check (capacity >= 0),
  location text not null default 'Gudang Utama',
  icon text not null default 'inventory_2_outlined',
  unit text not null default 'Kg',
  minimum_stock numeric not null default 0 check (minimum_stock >= 0),
  use_in_recipes boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  category text not null,
  batch_limit integer not null check (batch_limit > 0),
  stock integer not null default 0 check (stock >= 0),
  image text not null default 'assets/produk-ubi.png',
  photo_base64 text,
  ingredients text[] not null default '{}',
  recipe_items jsonb not null default '[]'::jsonb,
  recipe_yield_kg numeric check (recipe_yield_kg is null or recipe_yield_kg > 0),
  weight_per_piece_gram numeric
    check (weight_per_piece_gram is null or weight_per_piece_gram > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products
  add column if not exists recipe_items jsonb not null default '[]'::jsonb;

alter table public.products
  add column if not exists recipe_yield text;

alter table public.products
  add column if not exists recipe_yield_kg numeric
    check (recipe_yield_kg is null or recipe_yield_kg > 0);

alter table public.products
  add column if not exists weight_per_piece_gram numeric
    check (weight_per_piece_gram is null or weight_per_piece_gram > 0);

create table if not exists public.production_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  batch_code text not null,
  batch_count integer not null default 1 check (batch_count > 0),
  name text not null,
  produced integer not null check (produced >= 0),
  target integer not null check (target > 0),
  station text not null,
  image text not null default 'assets/produk-ubi.png',
  photo_base64 text,
  product_id uuid references public.products (id) on delete set null,
  material_usage jsonb not null default '[]'::jsonb,
  produced_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, batch_code)
);

alter table public.production_batches
  add column if not exists product_id uuid references public.products (id) on delete set null;

alter table public.production_batches
  add column if not exists material_usage jsonb not null default '[]'::jsonb;

alter table public.production_batches
  add column if not exists batch_count integer not null default 1
    check (batch_count > 0);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  table_name text not null,
  record_id text,
  record_name text,
  created_at timestamptz not null default now()
);

create index if not exists activity_logs_user_created_at_idx
  on public.activity_logs (user_id, created_at desc);

alter table public.production_batches
  add column if not exists photo_base64 text;

alter table public.profiles enable row level security;
alter table public.materials enable row level security;
alter table public.products enable row level security;
alter table public.production_batches enable row level security;
alter table public.activity_logs enable row level security;

create or replace function public.capture_activity_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed_row jsonb;
  actor_id uuid;
begin
  if tg_op = 'DELETE' then
    changed_row := to_jsonb(old);
  else
    changed_row := to_jsonb(new);
  end if;

  actor_id := coalesce(
    nullif(changed_row ->> 'user_id', '')::uuid,
    nullif(changed_row ->> 'id', '')::uuid
  );
  if actor_id is null then
    raise exception 'Could not identify the user for activity log entry';
  end if;

  insert into public.activity_logs (
    user_id,
    action,
    table_name,
    record_id,
    record_name
  )
  values (
    actor_id,
    tg_op,
    tg_table_name,
    coalesce(changed_row ->> 'id', changed_row ->> 'batch_code'),
    coalesce(
      nullif(changed_row ->> 'name', ''),
      nullif(changed_row ->> 'batch_code', ''),
      tg_table_name
    )
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on public.activity_logs from anon, authenticated;
grant select, delete on public.activity_logs to authenticated;

drop policy if exists "Users read their activity logs" on public.activity_logs;
create policy "Users read their activity logs" on public.activity_logs
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Users delete their activity logs" on public.activity_logs;
create policy "Users delete their activity logs" on public.activity_logs
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Users manage their profile" on public.profiles;
create policy "Users manage their profile" on public.profiles
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Users manage their materials" on public.materials;
create policy "Users manage their materials" on public.materials
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users manage their products" on public.products;
create policy "Users manage their products" on public.products
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users manage their production batches" on public.production_batches;
create policy "Users manage their production batches" on public.production_batches
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop trigger if exists capture_activity_log on public.profiles;
create trigger capture_activity_log
  after insert or update or delete on public.profiles
  for each row execute function public.capture_activity_log();

drop trigger if exists capture_activity_log on public.materials;
create trigger capture_activity_log
  after insert or update or delete on public.materials
  for each row execute function public.capture_activity_log();

drop trigger if exists capture_activity_log on public.products;
create trigger capture_activity_log
  after insert or update or delete on public.products
  for each row execute function public.capture_activity_log();

drop trigger if exists capture_activity_log on public.production_batches;
create trigger capture_activity_log
  after insert or update or delete on public.production_batches
  for each row execute function public.capture_activity_log();

create or replace function public.sync_product_stock_from_production_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.product_id is not null then
      update public.products
         set stock = stock + new.produced,
             updated_at = now()
       where id = new.product_id
         and user_id = new.user_id;
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if old.product_id is not null then
      update public.products
         set stock = greatest(stock - old.produced, 0),
             updated_at = now()
       where id = old.product_id
         and user_id = old.user_id;
    end if;
    return old;
  end if;

  if old.product_id is distinct from new.product_id then
    if old.product_id is not null then
      update public.products
         set stock = greatest(stock - old.produced, 0),
             updated_at = now()
       where id = old.product_id
         and user_id = old.user_id;
    end if;
    if new.product_id is not null then
      update public.products
         set stock = stock + new.produced,
             updated_at = now()
       where id = new.product_id
         and user_id = new.user_id;
    end if;
  elsif new.product_id is not null and new.produced <> old.produced then
    update public.products
       set stock = greatest(stock + new.produced - old.produced, 0),
           updated_at = now()
     where id = new.product_id
       and user_id = new.user_id;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_daily_production_batch_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  limit_count integer;
  existing_count bigint;
  old_batch_id uuid;
begin
  if new.product_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    old_batch_id := old.id;
  end if;

  select batch_limit
    into limit_count
    from public.products
   where id = new.product_id
     and user_id = new.user_id
   for update;
  if not found then
    raise exception 'Produk resep tidak ditemukan';
  end if;

  select coalesce(sum(batch_count), 0)
    into existing_count
    from public.production_batches
   where user_id = new.user_id
     and product_id = new.product_id
     and produced_on = new.produced_on
     and (old_batch_id is null or id <> old_batch_id);

  if existing_count + new.batch_count > limit_count then
    raise exception 'Batas % batch harian untuk produk % sudah tercapai',
      limit_count,
      new.name;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_daily_production_batch_limit
  on public.production_batches;
create trigger enforce_daily_production_batch_limit
  before insert or update of product_id, batch_count, produced_on
  on public.production_batches
  for each row execute function public.enforce_daily_production_batch_limit();

drop trigger if exists sync_product_stock_from_production_batch
  on public.production_batches;
create trigger sync_product_stock_from_production_batch
  after insert or update of product_id, produced or delete
  on public.production_batches
  for each row execute function public.sync_product_stock_from_production_batch();

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.materials to authenticated;
grant select, insert, update, delete on public.products to authenticated;
revoke insert, delete, update on public.production_batches from authenticated;
grant select on public.production_batches to authenticated;
grant update (
  batch_code,
  batch_count,
  name,
  produced,
  target,
  station,
  image,
  photo_base64,
  produced_on
) on public.production_batches to authenticated;

create or replace function public.create_production_batch_with_materials(
  p_batch jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  product_row public.products%rowtype;
  batch_row public.production_batches%rowtype;
  recipe_item jsonb;
  material_id uuid;
  material_name text;
  material_unit text;
  recipe_unit text;
  stock_quantity numeric;
  required_quantity numeric;
  recipe_quantity numeric;
  scale_factor numeric;
  produced_quantity integer;
  requested_batch_count integer;
  production_date date;
  daily_batch_count bigint;
  usage_rows jsonb := '[]'::jsonb;
begin
  if actor_id is null then
    raise exception 'Sesi login tidak ditemukan';
  end if;
  production_date := coalesce(
    nullif(p_batch ->> 'produced_on', '')::date,
    current_date
  );
  requested_batch_count := coalesce(
    nullif(p_batch ->> 'batch_count', '')::integer,
    1
  );
  if requested_batch_count <= 0 then
    raise exception 'Jumlah batch harus lebih dari 0';
  end if;
  if p_batch ->> 'product_id' is not null then
    select *
      into product_row
      from public.products
     where id = (p_batch ->> 'product_id')::uuid
       and user_id = actor_id
     for update;
    if not found then
      raise exception 'Produk resep tidak ditemukan';
    end if;
    select coalesce(sum(batch_count), 0)
      into daily_batch_count
      from public.production_batches
     where user_id = actor_id
       and product_id = product_row.id
       and produced_on = production_date;
    if daily_batch_count + requested_batch_count > product_row.batch_limit then
      raise exception 'Batas % batch harian untuk produk % sudah tercapai',
        product_row.batch_limit,
        product_row.name;
    end if;
    if jsonb_typeof(product_row.recipe_items) <> 'array' then
      raise exception 'Takaran bahan resep tidak valid';
    end if;
    if jsonb_array_length(product_row.recipe_items) = 0 then
      raise exception 'Resep produk belum memiliki takaran bahan';
    end if;
    if product_row.recipe_yield_kg is null or
        product_row.weight_per_piece_gram is null then
      raise exception
        'Isi hasil resep penuh (kg) dan berat per pcs (gram) pada data produk';
    end if;
    produced_quantity := (p_batch ->> 'produced')::integer;
    if produced_quantity is null or produced_quantity <= 0 then
      raise exception 'Jumlah produksi harus lebih dari 0 pcs';
    end if;
    scale_factor := produced_quantity * product_row.weight_per_piece_gram
      / (product_row.recipe_yield_kg * 1000);

    for recipe_item in
      select value
        from jsonb_array_elements(product_row.recipe_items)
       order by value ->> 'material_id'
    loop
      material_id := (recipe_item ->> 'material_id')::uuid;
      recipe_quantity := (recipe_item ->> 'quantity')::numeric;
      if recipe_quantity is null or recipe_quantity <= 0 then
        raise exception 'Takaran bahan resep harus lebih dari 0';
      end if;
      recipe_quantity := recipe_quantity * scale_factor;

      select name, unit, quantity
        into material_name, material_unit, stock_quantity
        from public.materials
       where id = material_id
         and user_id = actor_id
       for update;
      if not found then
        raise exception 'Bahan baku resep tidak ditemukan';
      end if;
      recipe_unit := lower(trim(coalesce(recipe_item ->> 'unit', material_unit)));
      if recipe_unit in ('gram', 'g') and lower(trim(material_unit)) = 'kg' then
        required_quantity := recipe_quantity / 1000;
      elsif recipe_unit = 'kg' and lower(trim(material_unit)) in ('gram', 'g') then
        required_quantity := recipe_quantity * 1000;
      elsif recipe_unit in ('ml', 'milliliter', 'millilitre')
          and lower(trim(material_unit)) in ('liter', 'litre', 'l') then
        required_quantity := recipe_quantity / 1000;
      elsif recipe_unit in ('liter', 'litre', 'l')
          and lower(trim(material_unit)) in ('ml', 'milliliter', 'millilitre') then
        required_quantity := recipe_quantity * 1000;
      elsif recipe_unit = lower(trim(material_unit))
          or (recipe_unit in ('gram', 'g')
              and lower(trim(material_unit)) in ('gram', 'g'))
          or (recipe_unit in ('liter', 'litre', 'l')
              and lower(trim(material_unit)) in ('liter', 'litre', 'l'))
          or (recipe_unit in ('ml', 'milliliter', 'millilitre')
              and lower(trim(material_unit)) in ('ml', 'milliliter', 'millilitre'))
          or (recipe_unit in ('pcs', 'piece', 'pieces')
              and lower(trim(material_unit)) in ('pcs', 'piece', 'pieces')) then
        required_quantity := recipe_quantity;
      else
        raise exception 'Satuan % tidak cocok dengan satuan stok %',
          recipe_item ->> 'unit',
          material_unit;
      end if;
      if stock_quantity < required_quantity then
        raise exception 'Stok % tidak cukup. Tersedia % %, dibutuhkan % %',
          material_name,
          stock_quantity,
          material_unit,
          required_quantity,
          material_unit;
      end if;

      update public.materials
         set quantity = quantity - required_quantity,
             updated_at = now()
       where id = material_id
         and user_id = actor_id;

      usage_rows := usage_rows || jsonb_build_array(
        jsonb_build_object(
          'material_id', material_id,
          'quantity', required_quantity
        )
      );
    end loop;
  end if;

  insert into public.production_batches (
    user_id,
    batch_code,
    batch_count,
    name,
    produced,
    target,
    station,
    image,
    photo_base64,
    product_id,
    material_usage,
    produced_on
  )
  values (
    actor_id,
    p_batch ->> 'batch_code',
    requested_batch_count,
    p_batch ->> 'name',
    (p_batch ->> 'produced')::integer,
    (p_batch ->> 'target')::integer,
    p_batch ->> 'station',
    coalesce(p_batch ->> 'image', 'assets/produk-ubi.png'),
    nullif(p_batch ->> 'photo_base64', ''),
    product_row.id,
    usage_rows,
    production_date
  )
  returning * into batch_row;

  return to_jsonb(batch_row);
end;
$$;

create or replace function public.delete_production_batch_restore_materials(
  p_batch_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  batch_row public.production_batches%rowtype;
  usage_row jsonb;
  material_id uuid;
  used_quantity numeric;
begin
  if actor_id is null then
    raise exception 'Sesi login tidak ditemukan';
  end if;

  select *
    into batch_row
    from public.production_batches
   where id = p_batch_id
     and user_id = actor_id
   for update;
  if not found then
    raise exception 'Batch produksi tidak ditemukan';
  end if;

  for usage_row in
    select value
      from jsonb_array_elements(batch_row.material_usage)
     order by value ->> 'material_id'
  loop
    material_id := (usage_row ->> 'material_id')::uuid;
    used_quantity := (usage_row ->> 'quantity')::numeric;
    if used_quantity is null or used_quantity <= 0 then
      raise exception 'Riwayat pemakaian bahan tidak valid';
    end if;

    update public.materials
       set quantity = quantity + used_quantity,
           updated_at = now()
     where id = material_id
       and user_id = actor_id;
    if not found then
      raise exception 'Bahan yang dipakai batch tidak ditemukan di inventori';
    end if;
  end loop;

  delete from public.production_batches
   where id = p_batch_id
     and user_id = actor_id;
end;
$$;

revoke all on function public.create_production_batch_with_materials(jsonb)
  from public, anon, authenticated;
grant execute on function public.create_production_batch_with_materials(jsonb)
  to authenticated;

revoke all on function public.delete_production_batch_restore_materials(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_production_batch_restore_materials(uuid)
  to authenticated;

notify pgrst, 'reload schema';
