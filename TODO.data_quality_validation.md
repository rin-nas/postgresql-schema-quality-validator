# Валидатор качества данных в БД

Рекомендовать скорректировать схему таблицы, если:
1. В nullable колонке нет ни одного значения null, если значений > 1000
1. Запрещать создавать строки без полезной нагрузки, когда есть только значения в автогенерируемых колонках
   (`id`, `created_at`, `updated_at`), а в других колонках везде `null`: 
   ```sql
   INSERT INTO person_last_subscription_access (person_id, subscription_id) VALUES (null, null), (null, null);
   --2 rows affected in 253 ms
   ```
