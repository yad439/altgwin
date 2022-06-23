create table packages (
  name text primary key,
  version text not null,
  path text not null,
  needs_update integer not null default 1
);
create table files (
  path text not null,
  name text not null,
  package_name text not null
  --foreign key package_id references packages (id)
);