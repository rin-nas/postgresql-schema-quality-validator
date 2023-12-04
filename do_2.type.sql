create type db_validation.schema_validate_checks as enum (
    'has_pk_uk',
    'has_not_redundant_index',
    'has_index_for_fk',
    'has_table_comment',
    'has_column_comment',
    'has_not_varchar_columns',
    'has_not_timestamp_columns',

    'valid_table_name',
    'valid_table_column_name',
    'valid_view_name',
    'valid_view_column_name',
    'valid_schema_name',
    'valid_trigger_name',
    'valid_procedure_name',
    'valid_function_name'
    /*
    --TODO
    'valid_constraint_name',
    'valid_type_name',
    'valid_domain_name',
    'valid_role_name'
    */
);

comment on type db_validation.schema_validate_checks is $$
Проверки в валидаторе качества схемы БД:
    has_pk_uk               - наличие первичного или уникального индекса в таблице
    has_not_redundant_index - отсутствие избыточных индексов в таблице
    has_index_for_fk        - наличие индексов для ограничений внешних ключей в таблице
    has_table_comment       - наличие описания для таблицы
    has_column_comment      - наличие описания для колонки
    has_not_varchar_columns   - отсутствие VARCHAR(n) колонок
    has_not_timestamp_columns - отсутствие timestamp колонок
    valid_table_name		- валидные названия таблиц
    valid_table_column_name - валидные названия колонок таблиц
    valid_view_name			- валидные названия представлений
    valid_view_column_name 	- валидные названия колонок представлений
    valid_trigger_name 		- валидные названия триггеров
    valid_schema_name 		- валидные названия схем
    valid_procedure_name	- валидные названия процедур
    valid_function_name		- валидные названия функций
$$;

-- alter type db_validation.schema_validate_checks owner to alexan;
