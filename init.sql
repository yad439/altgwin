create table packages (
  name text primary key,
  version text not null,
  path text not null,
  needs_update integer not null default 1
);
create table files (
  path text not null,
  name text not null,
  package_name text not null,
  foreign key(package_name) references packages(name)
);
create table dependencies (
  file text not null,
  dependency text not null
);

create index idx_files_package_name on files (package_name);
create index idx_files_path on files (path);
create unique index idx_packages_name on packages (name);
create index idx_dependencies_file on dependencies (file);