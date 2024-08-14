DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT 'ALTER SEQUENCE ' || sequence_schema || '.' || sequence_name || ' RESTART WITH 1;' AS alter_sequence_command
        FROM information_schema.sequences
        WHERE sequence_schema = 'netbox'
    LOOP
        EXECUTE r.alter_sequence_command;
    END LOOP;
END $$;

SELECT sequencename, last_value
FROM pg_sequences
WHERE schemaname = 'netbox';

SELECT
    n.nspname AS schema_name,
    t.relname AS table_name,
    a.attname AS column_name,
    s.relname AS sequence_name
FROM
    pg_class s
    JOIN pg_depend d ON d.objid = s.oid
    JOIN pg_attrdef ad ON ad.oid = d.refobjid
    JOIN pg_attribute a ON a.attnum = ad.adnum AND a.attrelid = ad.adrelid
    JOIN pg_class t ON t.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE
    s.relkind = 'S'  -- 'S' indicates a sequence
    AND s.relname = 'celery_taskmeta_id_seq';  -- Replace with your sequence name
