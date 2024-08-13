SELECT
        
        (custom_field_data->>'circuit_contract_expiry')::date AS circuit_contract_expiry,
        *
FROM
    "netbox"."circuits_circuit"
WHERESELECT
        
        (custom_field_data->>'circuit_contract_expiry')::date AS circuit_contract_expiry,
        *
FROM
    "netbox"."circuits_circuit"
WHERE
    (custom_field_data->>'circuit_contract_expiry')::date <= (CURRENT_DATE + INTERVAL '3.5 months');


SELECT
    cc.cid,
    (cc.custom_field_data->>'circuit_contract_expiry')::date AS circuit_contract_expiry,
    cp.name AS provider,
    ct.name AS type,
    cc.status,
    termination.*
FROM
    "netbox"."circuits_circuit" cc
JOIN
    "netbox"."circuits_provider" cp ON cc.provider_id = cp.id
JOIN
    "netbox"."circuits_circuittype" ct ON cc.type_id = ct.id
LEFT JOIN
    "netbox"."circuits_circuittermination" termination ON cc.termination_a_id = termination.id
WHERE
    (cc.custom_field_data->>'circuit_contract_expiry')::date <= (CURRENT_DATE + INTERVAL '3.5 months');

SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
JOIN
    information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN
    information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = 'netbox.circuits_circuit';

SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
JOIN
    information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN
    information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' and tc.table_schema = "gwr";

{"circ_org_mrc": null, "circ_org_otc": null, "circ_org_effective_rfs": null, "circ_org_potential_rfs": null, "circuit_contract_expiry": "2024-07-07", "circuit_contract_expiring_date": null}