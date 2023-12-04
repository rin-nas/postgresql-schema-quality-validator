-- валидация БД
insert into db_validation.schema_validate_config (
    checks,
    schemas_ignore_regexp, schemas_ignore,
    tables_ignore_regexp, tables_ignore,

    schema_name_regexp,
    table_name_regexp, table_column_name_regexp,
    view_name_regexp, view_column_name_regexp,
    trigger_name_regexp, procedure_name_regexp, function_name_regexp
    /*
    --TODO
    constraint_name_regexp,
    type_name_regexp,
    domain_name_regexp,
    role_name_regexp,
    */

)
select
    array[
        'has_pk_uk',
        'has_not_redundant_index',
        'has_index_for_fk',
        'has_table_comment',
        'has_column_comment',

        'valid_schema_name',
        'valid_table_name', 'valid_table_column_name',
        'valid_view_name', 'valid_view_column_name',
        'valid_trigger_name', 'valid_procedure_name', 'valid_function_name'
    ]::db_validation.schema_validate_checks[] as checks,
    null as schemas_ignore_regexp,
    null as schemas_ignore, --array['unused', 'migration', 'test']::regnamespace[],
    '(?<![a-z])(te?mp|test|unused|backups?|deleted)(?![a-z])' as tables_ignore_regexp,
    null as tables_ignore, --array['public._migration_versions']::regclass[]

    '^[a-z][a-z\d_\-]*[a-z\d]$' as schema_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as table_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as table_column_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as view_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as view_column_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as trigger_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as procedure_name_regexp,
    '^[a-z][a-z\d_\-]*[a-z\d]$' as function_name_regexp
;

-- TEST
table db_validation.schema_validate_config;
