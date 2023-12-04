--Валидатор схемы БД
create function db_validation.schema_validate()
    returns void
    stable
    --returns null on null input
    parallel safe
    language plpgsql
    set search_path = ''
AS $func$
DECLARE
    rec    record;
    config record;
BEGIN

    select * into config from db_validation.schema_validate_config order by id limit 1;

    config.schemas_ignore := coalesce(config.schemas_ignore, '{}') || '{information_schema,pg_catalog,pg_toast}';

    --Проверка на валидость имён колонок в представлении
    if config.checks is null or 'valid_view_column_name' = any(config.checks)
    then
        raise notice 'valid_view_column_name';

        select
            'Колонка в представлении имеет некорректное имя' as message,
            format('Колонка %I.%I.%I имеет некорректное имя %I', t.table_schema, t.table_name, c.column_name, c.column_name) as detail,
            format('Имя колонки должно соответствовать регулярному выражению: %s', config.view_column_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            t.table_schema as schema,
            t.table_name as table,
            c.column_name as column
        into rec
        from information_schema.columns as c
        inner join information_schema.tables as t on t.table_schema = c.table_schema
                                                 and t.table_name = c.table_name
                                                 and t.table_type = 'VIEW'
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)

        where true
		and c.column_name !~ config.view_column_name_regexp
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))

          -- исключаем таблицы-секции
          AND NOT EXISTS (SELECT
                          FROM   pg_catalog.pg_inherits AS i
                          WHERE  i.inhrelid = (t.table_schema || '.' || t.table_name)::regclass
        )
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён колонок в таблице
    if config.checks is null or 'valid_table_column_name' = any(config.checks)
    then
        raise notice 'valid_table_column_name';

        select
            'Колонка в таблице имеет некорректное имя' as message,
            format('Колонка %I.%I.%I имеет некорректное имя %I', t.table_schema, t.table_name, c.column_name, c.column_name) as detail,
            format('Имя колонки должно соответствовать регулярному выражению: %s', config.table_column_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            t.table_schema as schema,
            t.table_name as table,
            c.column_name as column
        into rec
        from information_schema.columns as c
        inner join information_schema.tables as t on t.table_schema = c.table_schema
                                                 and t.table_name = c.table_name
                                                 and t.table_type = 'BASE TABLE'
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)

        where true
		and c.column_name !~ config.table_column_name_regexp
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))

          -- исключаем таблицы-секции
          AND NOT EXISTS (SELECT
                          FROM   pg_catalog.pg_inherits AS i
                          WHERE  i.inhrelid = (t.table_schema || '.' || t.table_name)::regclass
        )
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён процедур
    if config.checks is null or 'valid_procedure_name' = any(config.checks)
    then
        raise notice 'valid_procedure_name';

        select
            'Процедура имеет некорректное имя' as message,
            format('Процедура %I.%I имеет некорректное имя %I', r.specific_schema, r.specific_name, r.specific_name) as detail,
            format('Имя процедуры должно соответствовать регулярному выражению: %s', config.procedure_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            r.specific_schema as schema
        into rec
        from information_schema.routines as r
        where r.specific_name !~ config.procedure_name_regexp
          and r.external_name is null --не выбирать все встроенные процедуры в базу (штатные, написаны на сях)
          and r.routine_type = 'PROCEDURE'
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR r.specific_schema !~ config.schemas_ignore_regexp)
          AND r.specific_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(r.specific_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён функций
    if config.checks is null or 'valid_function_name' = any(config.checks)
    then
        raise notice 'valid_function_name';

        select
            'Функция имеет некорректное имя' as message,
            format('Функция %I.%I имеет некорректное имя %I', r.specific_schema, r.specific_name, r.specific_name) as detail,
            format('Имя функции должно соответствовать регулярному выражению: %s', config.function_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            r.specific_schema as schema
        into rec
        from information_schema.routines as r
        where r.specific_name !~ config.function_name_regexp
          and r.external_name is null --не выбирать все встроенные функции в базу (штатные, написаны на сях)
          and r.routine_type = 'FUNCTION'
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR r.specific_schema !~ config.schemas_ignore_regexp)
          AND r.specific_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(r.specific_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён схем
    if config.checks is null or 'valid_schema_name' = any(config.checks)
    then
        raise notice 'valid_schema_name';

        select
            'Схема имеет некорректное имя' as message,
            format('Схема %I.%I имеет некорректное имя %I', t.schema_name) as detail,
            format('Имя схемы должно соответствовать регулярному регулярному выражению: %s', config.schema_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            t.schema_name as schema
        into rec
        from information_schema.schemata as t
        where schema_name !~ config.schema_name_regexp
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.schema_name !~ config.schemas_ignore_regexp)
          AND t.schema_name::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.schema_name, 'USAGE') --fix [42501] ERROR: permission denied for schema ...
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён представлений
    if config.checks is null or 'valid_view_name' = any(config.checks)
    then
        raise notice 'valid_view_name';

        select
            'Представление имеет некорректное имя' as message,
            format('Представление %I.%I имеет некорректное имя %I', t.table_schema, t.table_name, t.table_name) as detail,
            format('Имя представления должно соответствовать регулярному регулярному выражению: %s', config.view_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            t.table_schema as schema,
            t.table_name as "table"
        into rec
        from information_schema.tables as t
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)
        where t.table_type = 'VIEW'
          AND t.table_name !~ config.view_name_regexp

          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён триггеров
    if config.checks is null or 'valid_trigger_name' = any(config.checks)
    then
        raise notice 'valid_trigger_name';

        select
            'Триггер имеет некорректное имя' as message,
            format('Триггер %I.%I имеет некорректное имя %I', t.trigger_schema, t.trigger_name, t.trigger_name) as detail,
            format('Имя тригера должно соответствовать регулярному регулярному выражению: %s', config.trigger_name_regexp) as hint,
            '42602' /*invalid_name*/ as errcode,
            t.trigger_schema as schema,
            t.trigger_name as "table"
        into rec
        from information_schema.triggers as t
        cross join concat_ws('.', quote_ident(t.trigger_schema), quote_ident(t.trigger_name)) as p(trigger_full_name)
        where t.trigger_name !~ config.trigger_name_regexp
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.trigger_schema !~ config.schemas_ignore_regexp)
          AND t.trigger_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.trigger_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    --Проверка на валидость имён таблиц
    if config.checks is null or 'valid_table_name' = any(config.checks)
    then
        raise notice 'valid_table_name';

        select
        'Таблица имеет некорректное имя' as message,
        format('Таблица %I.%I имеет некорректное имя %I', t.table_schema, t.table_name, t.table_name) as detail,
        format('Имя таблицы должно соответствовать регулярному регулярному выражению: %s', config.table_name_regexp)  as hint,
        t.table_schema as schema,
        t.table_name as "table",
        '42602' /*invalid_name*/ as errcode
        into rec
        from information_schema.tables as t
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)
        where t.table_type = 'BASE TABLE'
          AND table_name !~ config.table_name_regexp

          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    if config.checks is null
       or 'has_not_varchar_columns' = any(config.checks) -- Отсутствие varchar(N)
       or 'has_not_timestamp_columns' = any(config.checks) -- Отсутствие timestamp колонок
    then
        raise notice 'check has_not_varchar_columns or has_not_timestamp_columns';

        select
            'Колонка имеет устаревший тип' as message,

            case when e.is_varchar then format('Колонка %I.%I.%I имеет устаревший тип %s(%s)', c.table_schema, c.table_name, c.column_name, c.udt_name, c.character_maximum_length)
                 when e.is_timestamp then format('Колонка %I.%I.%I имеет устаревший тип %s ', c.table_schema, c.table_name, c.column_name, c.udt_name)
            end as detail,

            case when e.is_varchar then
                     format(concat_ws(E'\n',
                             'Вместо типов char(n) и varchar(n) используйте тип text. Скорость чтения-записи не изменится.',
                             'Проверку на максимальную длину нужно сделать через ограничение CHECK. При этом лучше сразу задать ограничение на минимальную длину.',
                             --TODO в примере команды нужно корректно выводить значение колонки по умолчанию
                             E'Пример команды:\nALTER TABLE %I.%I ALTER COLUMN %I TYPE text DEFAULT NULL CHECK(length(%I) BETWEEN 1 AND %s)'
                            ),
                            c.table_schema, c.table_name, c.column_name, c.column_name, c.character_maximum_length
                           )
                 when e.is_timestamp then
                     format(concat_ws(E'\n',
                             'Вместо типa TIMESTAMP (WITHOUT TIME ZONE) используйте тип TIMESTAMPTZ (TIMESTAMP WITH TIME ZONE).',
                             --TODO в примере команды нужно корректно выводить значение колонки по умолчанию
                             E'Пример команды:\nALTER TABLE %I.%I ALTER COLUMN %I TYPE TIMESTAMPTZ(0) DEFAULT NOW() NOT NULL CHECK(%I <= now() + interval \'10m\')'
                            ),
                            c.table_schema, c.table_name, c.column_name, c.column_name, c.column_name
                           )
            end as hint,

            '42611' /*invalid column definition*/ as errcode,
            c.table_schema as schema,
            c.table_name as "table",
            c.column_name as "column",
            c.udt_name as datatype
        into rec
        from information_schema.columns as c
        inner join information_schema.tables as t on t.table_schema = c.table_schema
                                                 and t.table_name = c.table_name
                                                 and t.table_type = 'BASE TABLE'
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)

        inner join lateral (select
                    (c.udt_name in ('char', 'varchar', 'bpchar')
                    --если нет ограничения по длине то не трогаем тк это то же самое что TEXT
                    and c.character_maximum_length is not null --выводим только те, где есть ограничения длины
                    )
                    -- Закомментировал, т.к. это условие не учитывает максимальной длины элемента массива,
                    -- т.е. не отличает varchar[] и varchar(N)[].
                    -- Пример: select '{1234}'::varchar(2)[], '{1234}'::varchar[]
                    /*or
                      (c.data_type = 'ARRAY' -- проверяем массивы
                       and c.udt_name in ('_char', '_varchar','_bpchar') -- '_char%' '_varchar%' '_bpchar%' упрощено условие, выборка осталась неизменной
                      )*/
                    as is_varchar,

                    c.udt_name = 'timestamp'
                    --пока закомментировал, т.к. timestamp[] - это редкий случай и сообщение об ошибке нужно корректировать
                    /*or (
                        c.data_type = 'ARRAY'
                        and
                        c.udt_name = '_timestamp' --массивов с такими типами пока нет в базе, но могут появиться
                      )*/
                    as is_timestamp
        ) as e on case when config.checks is null or 'has_not_varchar_columns'   = any(config.checks) then e.is_varchar
                       when config.checks is null or 'has_not_timestamp_columns' = any(config.checks) then e.is_timestamp
                       else false
                  end
        where true
          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))

          -- исключаем таблицы-секции
          AND NOT EXISTS (SELECT
                          FROM   pg_catalog.pg_inherits AS i
                          WHERE  i.inhrelid = (t.table_schema || '.' || t.table_name)::regclass
        )
        limit 1;

        IF FOUND THEN
            -- https://www.postgrespro.ru/docs/postgresql/14/plpgsql-errors-and-messages
            RAISE EXCEPTION using
                message = rec.message,
                detail  = rec.detail,
                hint    = rec.hint,
                errcode = rec.errcode,
                column  = rec.column,
                --constraint = '',
                table    = rec.table,
                schema   = rec.schema,
                datatype = rec.datatype;
        END IF;

    end if;

    -- Наличие первичного или уникального индекса в таблице
    if config.checks is null or 'has_pk_uk' = any(config.checks) then
        raise notice 'check has_pk_uk';

        WITH t AS materialized (
            SELECT t.*
            FROM information_schema.tables AS t
            WHERE t.table_type = 'BASE TABLE'
            AND NOT EXISTS(SELECT
                             FROM information_schema.key_column_usage AS kcu
                            WHERE kcu.table_schema = t.table_schema
                              AND kcu.table_name = t.table_name
            )
        )
        SELECT *
        INTO rec
        FROM t
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)
        WHERE true
              -- исключаем схемы
              AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
              AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
              AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

              -- исключаем таблицы
              AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
              AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))
        ORDER BY t.table_schema, t.table_name
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'Таблица %.% должна иметь первичный или уникальный индекс!', rec.table_schema, rec.table_name;
        END IF;

    end if;

    -- Отсутствие избыточных индексов в таблице
    if config.checks is null or 'has_not_redundant_index' = any(config.checks) then
        raise notice 'check has_not_redundant_index';

        WITH index_data AS (
            SELECT x.*,
                   string_to_array(x.indkey::text, ' ')                  as key_array,
                   array_length(string_to_array(x.indkey::text, ' '), 1) as nkeys,
                   am.amname,
                   n.nspname AS table_schema,
                   c.relname AS table_name
            FROM pg_index AS x
            JOIN pg_class AS i ON i.oid = x.indexrelid
            JOIN pg_class c ON c.oid = x.indrelid
            JOIN pg_am am ON am.oid = i.relam
            LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE x.indisvalid --игнорируем "нерабочие" индексы, которые ещё создаются командой create index concurrently
        ),
        index_data2 AS (
            SELECT *
            FROM index_data AS t
            cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)
            WHERE true

            -- исключаем схемы
            AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
            AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
            AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

            -- исключаем таблицы
            AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
            AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))
        ),
        t AS (
             SELECT
                 i1.indrelid::regclass::text as table_name,
                 pg_get_indexdef(i1.indexrelid)                  main_index,
                 pg_get_indexdef(i2.indexrelid)                  redundant_index,
                 pg_size_pretty(pg_relation_size(i2.indexrelid)) redundant_index_size
             FROM index_data2 as i1
             JOIN index_data2 as i2 ON i1.indrelid = i2.indrelid
                  AND i1.indexrelid <> i2.indexrelid
                  AND i1.amname = i2.amname
             WHERE (regexp_replace(i1.indpred, 'location \d+', 'location', 'g') IS NOT DISTINCT FROM
                    regexp_replace(i2.indpred, 'location \d+', 'location', 'g'))
               AND (regexp_replace(i1.indexprs, 'location \d+', 'location', 'g') IS NOT DISTINCT FROM
                    regexp_replace(i2.indexprs, 'location \d+', 'location', 'g'))
               AND ((i1.nkeys > i2.nkeys and not i2.indisunique)
                 OR (i1.nkeys = i2.nkeys and
                     ((i1.indisunique and i2.indisunique and (i1.indexrelid > i2.indexrelid)) or
                      (not i1.indisunique and not i2.indisunique and
                       (i1.indexrelid > i2.indexrelid)) or
                      (i1.indisunique and not i2.indisunique)))
                 )
               AND i1.key_array[1:i2.nkeys] = i2.key_array
             ORDER BY pg_relation_size(i2.indexrelid) desc,
                      i1.indexrelid::regclass::text,
                      i2.indexrelid::regclass::text
         )
         SELECT DISTINCT ON (redundant_index) t.* INTO rec FROM t LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION E'Таблица % уже имеет индекс %\nУдалите избыточный индекс %', rec.table_name, rec.main_index, rec.redundant_index;
        END IF;

    end if;

    -- Наличие индексов для ограничений внешних ключей в таблице
    if config.checks is null or 'has_index_for_fk' = any(config.checks) then
        raise notice 'check has_index_for_fk';

        -- запрос для получения FK без индексов, взял по ссылке ниже и модифицировал
        -- https://github.com/NikolayS/postgres_dba/blob/master/sql/i3_non_indexed_fks.sql
        with fk_actions ( code, action ) as (
            values ('a', 'error'),
                   ('r', 'restrict'),
                   ('c', 'cascade'),
                   ('n', 'set null'),
                   ('d', 'set default')
        ), fk_list as (
            select
                pg_constraint.oid as fkoid, conrelid, confrelid as parentid,
                conname,
                relname,
                nspname,
                fk_actions_update.action as update_action,
                fk_actions_delete.action as delete_action,
                conkey as key_cols
            from pg_constraint
            join pg_class on conrelid = pg_class.oid
            join pg_namespace on pg_class.relnamespace = pg_namespace.oid
            join fk_actions as fk_actions_update on confupdtype = fk_actions_update.code
            join fk_actions as fk_actions_delete on confdeltype = fk_actions_delete.code
            where contype = 'f'
        ), fk_attributes as (
            select fkoid, conrelid, attname, attnum
            from fk_list
                     join pg_attribute on conrelid = attrelid and attnum = any(key_cols)
            order by fkoid, attnum
        ), fk_cols_list as (
            select fkoid, array_agg(attname) as cols_list
            from fk_attributes
            group by fkoid
        ), index_list as (
            select
                indexrelid as indexid,
                pg_class.relname as indexname,
                indrelid,
                indkey,
                indpred is not null as has_predicate,
                pg_get_indexdef(indexrelid) as indexdef
            from pg_index
            join pg_class on indexrelid = pg_class.oid
            where indisvalid
        ), fk_index_match as (
            select
                fk_list.*,
                indexid,
                indexname,
                indkey::int[] as indexatts,
                has_predicate,
                indexdef,
                array_length(key_cols, 1) as fk_colcount,
                array_length(indkey,1) as index_colcount,
                round(pg_relation_size(conrelid)/(1024^2)::numeric) as table_mb,
                cols_list
            from fk_list
            join fk_cols_list using (fkoid)
            left join index_list on conrelid = indrelid
                                and (indkey::int2[])[0:(array_length(key_cols,1) -1)] operator(pg_catalog.@>) key_cols

        ), fk_perfect_match as (
            select fkoid
            from fk_index_match
            where (index_colcount - 1) <= fk_colcount
              and not has_predicate
              and indexdef like '%USING btree%'
        ), fk_index_check as (
            select 'no index' as issue, *, 1 as issue_sort
            from fk_index_match
            where indexid is null
            /*union all
            select 'questionable index' as issue, *, 2
            from fk_index_match
            where
                indexid is not null
              and fkoid not in (select fkoid from fk_perfect_match)*/
        ), parent_table_stats as (
            select
                fkoid,
                tabstats.relname as parent_name,
                (n_tup_ins + n_tup_upd + n_tup_del + n_tup_hot_upd) as parent_writes,
                round(pg_relation_size(parentid)/(1024^2)::numeric) as parent_mb
            from pg_stat_user_tables as tabstats
                     join fk_list on relid = parentid
        ), fk_table_stats as (
            select
                fkoid,
                (n_tup_ins + n_tup_upd + n_tup_del + n_tup_hot_upd) as writes,
                seq_scan as table_scans
            from pg_stat_user_tables as tabstats
                     join fk_list on relid = conrelid
        ), result as (
            select
                nspname as schema_name,
                relname as table_name,
                conname as fk_name,
                issue,
                table_mb,
                writes,
                table_scans,
                parent_name,
                parent_mb,
                parent_writes,
                cols_list,
                coalesce(indexdef, 'CREATE INDEX /*CONCURRENTLY*/ ' || relname || '_' || cols_list[1] || ' ON ' ||
                                   quote_ident(nspname) || '.' || quote_ident(relname) || ' (' || quote_ident(cols_list[1]) || ')') as indexdef
            from fk_index_check
                     join parent_table_stats using (fkoid)
                     join fk_table_stats using (fkoid)
            where
                true /*table_mb > 9*/
              and (
                /*    writes > 1000
                or parent_writes > 1000
                or parent_mb > 10*/
                true
                )
              and issue = 'no index'
            order by issue_sort, table_mb asc, table_name, fk_name
            limit 1
        )
        select * into rec from result;

        IF FOUND THEN
            RAISE EXCEPTION E'Отсутствует индекс для внешнего ключа\nДобавьте индекс: %', rec.indexdef;
        END IF;

    end if;

    if config.checks is null or 'has_table_comment' = any(config.checks) then
        raise notice 'check has_table_comment';

        select --obj_description((t.table_schema || '.' || t.table_name)::regclass::oid),
               format($$comment on table %I.%I is '...';$$, t.table_schema, t.table_name) as sql
               --*,
               --t.table_schema, t.table_name
        into rec
        from information_schema.tables as t
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)
        where t.table_type = 'BASE TABLE'
          and coalesce(trim(obj_description((t.table_schema || '.' || t.table_name)::regclass::oid)), '') in ('', t.table_name)

          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))

          -- исключаем таблицы-секции
          AND NOT EXISTS (SELECT
                          FROM   pg_catalog.pg_inherits AS i
                          WHERE  i.inhrelid = (t.table_schema || '.' || t.table_name)::regclass
          )

        order by 1
        limit 1;

        IF FOUND THEN
            RAISE EXCEPTION E'Для таблицы отсутствует описание или совпадает с названием\nДобавьте его: %', rec.sql;
        END IF;

    end if;

    if config.checks is null or 'has_column_comment' = any(config.checks) then
        raise notice 'check has_column_comment';

        select --col_description((c.table_schema || '.' || t.table_name)::regclass::oid, c.ordinal_position) as column_comment,
               format($$comment on column %I.%I.%I is '...';$$, t.table_schema, t.table_name, c.column_name) as sql
        into rec
        from information_schema.columns as c
        inner join information_schema.tables as t on t.table_schema = c.table_schema
                                                 and t.table_name = c.table_name
                                                 and t.table_type = 'BASE TABLE'
        cross join concat_ws('.', quote_ident(t.table_schema), quote_ident(t.table_name)) as p(table_full_name)
        where c.column_name != 'id'
          and coalesce(trim(col_description((c.table_schema || '.' || t.table_name)::regclass::oid, c.ordinal_position)), '') in ('', c.column_name)

          -- исключаем схемы
          AND (config.schemas_ignore_regexp is null OR t.table_schema !~ config.schemas_ignore_regexp)
          AND t.table_schema::regnamespace != ALL (config.schemas_ignore)
          AND pg_catalog.has_schema_privilege(t.table_schema, 'USAGE') --fix [42501] ERROR: permission denied for schema ...

          -- исключаем таблицы
          AND (config.tables_ignore_regexp is null OR p.table_full_name !~ config.tables_ignore_regexp)
          AND (config.tables_ignore is null OR p.table_full_name::regclass != ALL (config.tables_ignore))

          -- исключаем таблицы-секции
          AND NOT EXISTS (SELECT
                          FROM   pg_catalog.pg_inherits AS i
                          WHERE  i.inhrelid = (t.table_schema || '.' || t.table_name)::regclass
          )

        order by 1
        limit 1;

        IF FOUND THEN
            RAISE EXCEPTION E'Для колонки таблицы отсутствует описание или совпадает с названием\nДобавьте его: %', rec.sql;
        END IF;

    end if;

END
$func$;

-- alter function db_validation.schema_validate() owner to alexan;

-- TEST
-- запускаем валидатор БД
select db_validation.schema_validate();
