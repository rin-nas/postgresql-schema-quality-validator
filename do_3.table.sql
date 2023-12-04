drop table if exists db_validation.schema_validate_config;

create table db_validation.schema_validate_config (
    id int generated always as identity primary key,

    checks db_validation.schema_validate_checks[] check(cardinality(db_validation.array_unique(checks)) = cardinality(checks)
                                                        and cardinality(checks) > 0),

    schemas_ignore_regexp text check (schemas_ignore_regexp != ''
                                      and trim(schemas_ignore_regexp) = schemas_ignore_regexp
                                      and db_validation.is_regexp(schemas_ignore_regexp)),

    schemas_ignore regnamespace[] check(cardinality(db_validation.array_unique(schemas_ignore)) = cardinality(schemas_ignore)
                                        and cardinality(schemas_ignore) > 0),

    tables_ignore_regexp  text check (tables_ignore_regexp != ''
                                      and trim(tables_ignore_regexp) = tables_ignore_regexp
                                      and db_validation.is_regexp(tables_ignore_regexp) ),

    tables_ignore  regclass[] check(cardinality(db_validation.array_unique(tables_ignore)) = cardinality(tables_ignore)
                                    and cardinality(tables_ignore) > 0),

    /*
    --TODO https://github.com/rin-nas/postgresql-patterns-library/blob/master/types/table_column_type.sql
    table_columns_ignore db_validation.table_column_type[] check(
        cardinality(depers.array_unique(table_column_type)) = cardinality(table_column_type)
        and cardinality(table_column_type) > 0
    ),
    --TODO https://github.com/rin-nas/postgresql-patterns-library/blob/master/types/view_column_type.sql
    view_columns_ignore db_validation.view_column_type[] check(
        cardinality(depers.array_unique(view_column_type)) = cardinality(view_column_type)
        and cardinality(view_column_type) > 0
    ),
    */

    table_name_regexp        text check ( db_validation.is_regexp(table_name_regexp) ),
    table_column_name_regexp text check ( db_validation.is_regexp(table_column_name_regexp) ),
    view_name_regexp         text check ( db_validation.is_regexp(view_name_regexp) ),
    view_column_name_regexp  text check ( db_validation.is_regexp(view_column_name_regexp) ),
    trigger_name_regexp      text check ( db_validation.is_regexp(trigger_name_regexp) ),
    schema_name_regexp       text check ( db_validation.is_regexp(schema_name_regexp) ),
    procedure_name_regexp    text check ( db_validation.is_regexp(procedure_name_regexp) ),
    function_name_regexp     text check ( db_validation.is_regexp(function_name_regexp) ),

    /*
    --TODO
    constraint_name_regexp   text check ( db_validation.is_regexp(constraint_name_regexp) ),
    type_name_regexp         text check ( db_validation.is_regexp(type_name_regexp) ),
    domain_name_regexp       text check ( db_validation.is_regexp(domain_name_regexp) ),
    role_name_regexp         text check ( db_validation.is_regexp(role_name_regexp) ),
    */

    created_at timestamptz(0) not null default now() check (created_at <= now()::timestamptz(0)),
    updated_at timestamptz(0) not null default now() check (updated_at <= now()::timestamptz(0)),
    check (created_at <= updated_at)
);

-- alter table db_validation.schema_validate_config owner to alexan;

comment on table db_validation.schema_validate_config is 'Конфигурация валидатора качества схемы БД для текущей БД';
comment on column db_validation.schema_validate_config.id is 'ID';
comment on column db_validation.schema_validate_config.checks is $$
Список проверок (массив строк)
* Если передан null - то все возможные проверки
* Если передан пустой массив - то ни одной проверки
$$;
comment on column db_validation.schema_validate_config.schemas_ignore_regexp is 'Регулярное выражение со схемами, которые нужно проигнорировать';
comment on column db_validation.schema_validate_config.schemas_ignore is $$
Список схем, которые нужно проигнорировать
В список схем автоматически добавляются служебные схемы "information_schema" и "pg_catalog", указывать их явно не нужно
$$;
comment on column db_validation.schema_validate_config.tables_ignore_regexp is 'Регулярное выражение с таблицами (с указанием схемы), которые нужно проигнорировать';
comment on column db_validation.schema_validate_config.tables_ignore is 'Список таблиц в формате {schema}.{table}, которые нужно проигнорировать';

comment on column db_validation.schema_validate_config.table_name_regexp        is 'Регулярное выражение для валидации названий таблиц';
comment on column db_validation.schema_validate_config.table_column_name_regexp is 'Регулярное выражение для валидации названий колонок таблиц';
comment on column db_validation.schema_validate_config.view_name_regexp         is 'Регулярное выражение для валидации названий представлений';
comment on column db_validation.schema_validate_config.view_column_name_regexp  is 'Регулярное выражение для валидации названий колонок представлений';
comment on column db_validation.schema_validate_config.trigger_name_regexp      is 'Регулярное выражение для валидации названий триггеров';
comment on column db_validation.schema_validate_config.schema_name_regexp       is 'Регулярное выражение для валидации названий схем';
comment on column db_validation.schema_validate_config.procedure_name_regexp    is 'Регулярное выражение для валидации названий процедур';
comment on column db_validation.schema_validate_config.function_name_regexp     is 'Регулярное выражение для валидации названий функций';

/*
--TODO
comment on column db_validation.schema_validate_config.constraint_name_regexp is 'Регулярное выражение для валидации названий ограничений';
comment on column db_validation.schema_validate_config.type_name_regexp       is 'Регулярное выражение для валидации названий типов';
comment on column db_validation.schema_validate_config.domain_name_regexp     is 'Регулярное выражение для валидации названий доменов';
comment on column db_validation.schema_validate_config.role_name_regexp       is 'Регулярное выражение для валидации названий ролей';
*/
