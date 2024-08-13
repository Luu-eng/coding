-
- name: insert-fuzzy-address-matches
WITH
    _sub_address AS (
        SELECT
            _sub.id,
            REGEXP_REPLACE(
                TRIM(
                    LOWER((_sub.contact ->> 'street'))
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            TRIM(
                LOWER(
                    _sub.contact ->> 'streetNumber'
                )
            ) AS house_number,
            LEFT(((_sub.contact ->> 'zip')), 4) AS postal_code
        FROM accessapi.subscription AS _sub
            LEFT JOIN accessapi.gwr_match AS gm ON _sub.id = gm.subscription_id
        WHERE
            gm.subscription_id IS NULL
    ),
    _gwr_building AS (
        SELECT DISTINCT
            ON (egid) egid
        FROM gwr.building
        WHERE
            status NOT IN (
                'unusable',
                'demolished',
                'unrealised'
            )
    ),
    _gwr_address AS (
        SELECT
            _e.egaid,
            REGEXP_REPLACE(
                TRIM(LOWER((_s.name))),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            REGEXP_REPLACE(
                TRIM(LOWER((_s.abbreviation))),
                '[\s.-]+',
                '',
                'g'
            ) AS street_abbreviation,
            TRIM(
                LOWER(CAST(_e.house_number AS TEXT))
            ) AS house_number,
            CAST(_e.postal_code AS TEXT) AS postal_code
        FROM
            gwr.entrance AS _e
            INNER JOIN _gwr_building AS _b ON _b.egid = _e.egid
            INNER JOIN gwr.street AS _s ON _e.esid = _s.esid
    )
INSERT INTO
    accessapi.gwr_match (subscription_id, egaid)
SELECT a.id, g.egaid
FROM
    _sub_address AS a
    INNER JOIN _gwr_address AS g ON (a.postal_code = g.postal_code)
    AND (
        a.street_name = g.street_name
        OR a.street_name = g.street_abbreviation
    )
    AND a.house_number = g.house_number
WHERE
    g.egaid IS NOT NULL;

-- name: insert-full-address-matches
WITH
    _sub_address AS (
        SELECT
            _sub.id,
            REGEXP_REPLACE(
                TRIM(
                    LOWER((_sub.contact ->> 'street'))
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            REGEXP_REPLACE(
                TRIM(
                    LOWER((_sub.contact ->> 'city'))
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS locality,
            TRIM(
                LOWER(
                    _sub.contact ->> 'streetNumber'
                )
            ) AS house_number,
            LEFT(((_sub.contact ->> 'zip')), 4) AS postal_code
        FROM accessapi.subscription AS _sub
    ),
    _gwr_building AS (
        SELECT DISTINCT
            ON (egid) egid
        FROM gwr.building
        WHERE
            status NOT IN (
                'unusable',
                'demolished',
                'unrealised'
            )
    ),
    _gwr_address AS (
        SELECT
            _e.egaid,
            REGEXP_REPLACE(
                TRIM(LOWER((_s.name))),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            REGEXP_REPLACE(
                TRIM(LOWER((_e.locality))),
                '[\s.-]+',
                '',
                'g'
            ) AS location,
            REGEXP_REPLACE(
                TRIM(LOWER((_s.abbreviation))),
                '[\s.-]+',
                '',
                'g'
            ) AS street_abbreviation,
            TRIM(
                LOWER(CAST(_e.house_number AS TEXT))
            ) AS house_number,
            CAST(_e.postal_code AS TEXT) AS postal_code
        FROM
            gwr.entrance AS _e
            INNER JOIN _gwr_building AS _b ON _b.egid = _e.egid
            INNER JOIN gwr.street AS _s ON _e.esid = _s.esid
    )
INSERT INTO
    accessapi.gwr_match (subscription_id, egaid)
SELECT a.id, COALESCE(MIN(g.egaid), NULL) AS egaid
FROM
    _sub_address AS a
    LEFT JOIN _gwr_address AS g ON (a.postal_code = g.postal_code)
    AND (
        a.street_name = g.street_name
        OR a.street_name = g.street_abbreviation
    )
    AND a.house_number = g.house_number
    AND a.locality LIKE '%' || g.location || '%'
GROUP BY
    a.id
ON CONFLICT (subscription_id) DO
UPDATE
SET
    egaid = EXCLUDED.egaid,
    updated_at = CURRENT_TIMESTAMP
WHERE
    accessapi.gwr_match.egaid IS DISTINCT FROM EXCLUDED.egaid;

-- name: check-for-unmatched-subscriptions
SELECT
    gm.subscription_id,
    gm.egaid,
    s.contact ->> 'firstName' AS first_name,
    s.contact ->> 'lastName' AS last_name,
    s.contact ->> 'street' AS street,
    s.contact ->> 'streetNumber' AS street_number,
    s.contact ->> 'zip' AS postal_code,
    s.contact ->> 'city' AS city
FROM accessapi.gwr_match gm
    JOIN accessapi.subscription s ON gm.subscription_id = s.id
WHERE
    gm.egaid IS NULL
    and s.state = 'RUNNING';

SELECT
    e.house_number,
    s.name AS street_name,
    e.postal_code,
    e.is_official,
    COUNT(*) as occurrences
FROM gwr.entrance e
    JOIN gwr.street s ON e.esid = s.esid
WHERE
    e.is_official = true
GROUP BY
    e.house_number,
    e.postal_code,
    s.name,
    e.is_official
HAVING
    COUNT(*) > 1;

SELECT e.house_number, e.locality, s.name, e.postal_code, e.is_official, COUNT(*) as occurrences
FROM gwr.entrance e
    JOIN gwr.street s ON e.esid = s.esid
WHERE
    e.is_official = true
GROUP BY
    e.house_number,
    e.locality,
    e.postal_code,
    s.name
HAVING
    COUNT(*) > 1;

WHERE

SELECT *
FROM gwr.entrance e
    JOIN gwr.street s ON e.esid = s.esid
WHERE
    e.house_number = '24'
    AND s.name = 'Untere Zellstr.'
    AND postal_code = '3970';

SELECT *
FROM accessapi.gwr_match e
WhERE e.egaid = 101785418;

SELECT *
FROM accessapi.gwr_match
    LEFT JOIN gwr.entrance s ON accessapi.gwr_match.egaid = s.egaid

WITH
    duplicate_entries AS (
        SELECT
            e.house_number,
            e.locality,
            s.name AS street_name,
            e.postal_code,
            COUNT(*) as occurrences
        FROM gwr.entrance e
            JOIN gwr.street s ON e.esid = s.esid
        GROUP BY
            e.house_number,
            e.locality,
            e.postal_code,
            s.name
        HAVING
            COUNT(*) > 1
    )
SELECT e.*, s.*
FROM
    gwr.entrance e
    JOIN gwr.street s ON e.esid = s.esid
    JOIN duplicate_entries d ON e.house_number = d.house_number
    AND e.locality = d.locality
    AND e.postal_code = d.postal_code
    AND s.name = d.street_name;

WITH
    duplicate_entries AS (
        SELECT
            e.house_number,
            e.locality,
            s.name AS street_name,
            e.postal_code,
            COUNT(*) as occurrences
        FROM gwr.entrance e
            JOIN gwr.street s ON e.esid = s.esid
        GROUP BY
            e.house_number,
            e.locality,
            e.postal_code,
            s.name
        HAVING
            COUNT(*) > 1
    )
SELECT e.house_number, e.locality, e.postal_code, s.name, e.is_official
FROM
    gwr.entrance e
    JOIN gwr.street s ON e.esid = s.esid
    JOIN duplicate_entries d ON e.house_number = d.house_number
    AND e.locality = d.locality
    AND e.postal_code = d.postal_code
    AND s.name = d.street_name
ORDER BY e.postal_code;

SELECT e.esid, e.house_number, e.postal_code, e.locality
FROM gwr.entrance e
GROUP BY
    e.esid,
    e.house_number,
    e.postal_code,
    e.locality
HAVING
    COUNT(*) > 1
SELECT

WITH
    duplicate_entries AS (
        SELECT
            e.house_number,
            e.locality,
            e.esid AS street_name,
            e.postal_code,
            COUNT(*) as occurrences
        FROM gwr.entrance e
        GROUP BY
            e.house_number,
            e.locality,
            e.postal_code,
            e.esid
        HAVING
            COUNT(*) > 1
    )
SELECT e.house_number, e.locality, e.postal_code, e.esid, e.is_official
FROM
    gwr.entrance e
    JOIN duplicate_entries d ON e.house_number = d.house_number
    AND e.locality = d.locality
    AND e.postal_code = d.postal_code
ORDER BY e.postal_code;

WITH
    duplicate_entries AS (
        SELECT
            e.house_number,
            e.locality,
            e.esid AS street_name,
            e.postal_code,
            COUNT(*) as occurrences
        FROM gwr.entrance e
        GROUP BY
            e.house_number,
            e.locality,
            e.postal_code,
            e.esid
        HAVING
            COUNT(*) > 1
    )
SELECT e.house_number, e.locality, e.postal_code, e.esid, e.is_official, e.egaid
FROM
    gwr.entrance e
    Inner JOIN duplicate_entries d ON e.house_number = d.house_number
    AND e.locality = d.locality
    AND e.postal_code = d.postal_code
    AND e.esid = d.street_name
ORDER BY e.postal_code;

WITH
    duplicate_entries AS (
        SELECT
            e.house_number,
            e.locality,
            e.esid AS street_name,
            e.postal_code,
            COUNT(*) as occurrences
        FROM gwr.entrance e
        GROUP BY
            e.house_number,
            e.locality,
            e.postal_code,
            e.esid
        HAVING
            COUNT(*) > 1
    )
SELECT e.house_number, e.locality, e.postal_code, e.esid, e.is_official
FROM
    gwr.entrance e
    AND e.locality = d.locality
    AND e.postal_code = d.postal_code
    AND e.esid = d.street_name
    JOIN duplicate_entries d ON e.house_number = d.house_number
ORDER BY e.postal_code;


-- name: check-for-matched-subscriptions
SELECT
    gm.subscription_id,
    gm.egaid,
    s.contact ->> 'firstName' AS first_name,
    s.contact ->> 'lastName' AS last_name,
    s.contact ->> 'street' AS street,
    s.contact ->> 'streetNumber' AS street_number,
    s.contact ->> 'zip' AS postal_code,
    s.contact ->> 'city' AS city
FROM accessapi.gwr_match gm
    JOIN accessapi.subscription s ON gm.subscription_id = s.id
WHERE
    s.state = 'RUNNING';

SELECT
    s.id AS subscription_id,
    s.contact ->> 'firstName' AS first_name,
    s.contact ->> 'lastName' AS last_name,
    s.contact ->> 'street' AS street,
    s.contact ->> 'streetNumber' AS street_number,
    s.contact ->> 'zip' AS postal_code,
    s.contact ->> 'city' AS city
FROM accessapi.subscription s
LEFT JOIN accessapi.gwr_match gm ON s.id = gm.subscription_id
WHERE gm.subscription_id IS NULL and s.contact IS NOT NULL;

SELECT * from accessapi.gwr_match where accessapi.gwr_match.subscription_id = 8;



WITH
    _sub_address AS (
        SELECT
            _sub.id,
            REGEXP_REPLACE(
                TRIM(
                    LOWER(
                         (_sub.contact ->> 'street')
                    )
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            TRIM(
                LOWER(
                    _sub.contact ->> 'streetNumber'
                )
            ) AS house_number,
            LEFT(((_sub.contact ->> 'zip')), 4) AS postal_code
        FROM accessapi.subscription AS _sub
            LEFT JOIN accessapi.gwr_match AS gm ON _sub.id = gm.subscription_id
        WHERE
            gm.subscription_id IS NULL
    ),
    _gwr_building AS (
        SELECT DISTINCT
            ON (egid) egid
        FROM gwr.building
        WHERE
            status NOT IN (
                'unusable',
                'demolished',
                'unrealised'
            )
    ),
    _gwr_address AS (
        SELECT
            _e.egaid,
            REGEXP_REPLACE(
                TRIM(LOWER( (_s.name))),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            REGEXP_REPLACE(
                TRIM(
                    LOWER( (_s.abbreviation))
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS street_abbreviation,
            TRIM(
                LOWER(CAST(_e.house_number AS TEXT))
            ) AS house_number,
            CAST(_e.postal_code AS TEXT) AS postal_code,
            _e.is_official AS is_official
        FROM
            gwr.entrance AS _e
            INNER JOIN _gwr_building AS _b ON _b.egid = _e.egid
            INNER JOIN gwr.street AS _s ON _e.esid = _s.esid
    )
SELECT a.id, g.egaid
FROM
    _sub_address AS a
    LEFT JOIN _gwr_address AS g ON (a.postal_code = g.postal_code)
    AND (
        a.street_name = g.street_name
        OR a.street_name = g.street_abbreviation
    )
    AND a.house_number = g.house_number
WHERE
    g.egaid IS NOT NULL
    AND g.is_official = true
GROUP BY
    a.id, g.egaid
HAVING
    COUNT(g.egaid) = 0;


UPDATE core_user
SET is_superuser = true
WHERE id=36;

SELECT 
    accessapi.subscription.id AS sub_id,
    (
        SELECT SUM()
        FROM orders
        WHERE orders.customer_id = customers.id
    ) AS total_spent
FROM
    customers


SELECT *
FROM gwr.entrance e
JOIN gwr.street s ON e.esid = s.esid
WHERE
    TRIM(
                LOWER(CAST(e.house_number AS TEXT))
            ) = TRIM(
                LOWER(CAST('24' AS TEXT))
            )
    AND REGEXP_REPLACE(
            TRIM(
                LOWER(s.abbreviation)
            ),
            '[\s.-]+',
            '',
            'g'
        ) = REGEXP_REPLACE(
            TRIM(
                LOWER('Untere Zellstr.')
            ),
            '[\s.-]+',
            '',
            'g'
        )
    AND CAST(e.postal_code AS TEXT) = LEFT((('3970')), 4) 
    AND e.is_official = true


SELECT 
    s.id AS subscription_id,
    s.contact ->> 'firstName' AS first_name,
    s.contact ->> 'lastName' AS last_name,
    s.contact ->> 'street' AS street,
    s.contact ->> 'streetNumber' AS street_number,
    s.contact ->> 'zip' AS postal_code,
    s.contact ->> 'city' AS city,
    o.egaid
FROM
    accessapi.subscription s
LEFT JOIN 
    accessapi.gwr_match o ON s.id = o.subscription_id
WHERE
    o.egaid IS NULL 
    AND s.state = 'RUNNING';




WITH
    _sub_address AS (
        SELECT
            _sub.id,
            REGEXP_REPLACE(
                TRIM(
                    LOWER(
                         (_sub.contact ->> 'street')
                    )
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            TRIM(
                LOWER(
                    _sub.contact ->> 'streetNumber'
                )
            ) AS house_number,
            LEFT(((_sub.contact ->> 'zip')), 4) AS postal_code
        FROM accessapi.subscription AS _sub
            LEFT JOIN accessapi.gwr_match AS gm ON _sub.id = gm.subscription_id
        WHERE
            gm.subscription_id IS NULL
    ),
    _gwr_building AS (
        SELECT DISTINCT
            ON (egid) egid
        FROM gwr.building
        WHERE
            status NOT IN (
                'unusable',
                'demolished',
                'unrealised'
            )
    ),
    _gwr_address AS (
        SELECT
            _e.egaid,
            REGEXP_REPLACE(
                TRIM(LOWER( (_s.name))),
                '[\s.-]+',
                '',
                'g'
            ) AS street_name,
            REGEXP_REPLACE(
                TRIM(
                    LOWER( (_s.abbreviation))
                ),
                '[\s.-]+',
                '',
                'g'
            ) AS street_abbreviation,
            TRIM(
                LOWER(CAST(_e.house_number AS TEXT))
            ) AS house_number,
            CAST(_e.postal_code AS TEXT) AS postal_code
        FROM
            gwr.entrance AS _e
            INNER JOIN _gwr_building AS _b ON _b.egid = _e.egid
            INNER JOIN gwr.street AS _s ON _e.esid = _s.esid
    )
SELECT g.egaid AS egaid
FROM _sub_address AS a
LEFT JOIN _gwr_address AS g ON (a.postal_code = g.postal_code)
    AND (
        a.street_name = g.street_name
        OR a.street_name = g.street_abbreviation
    )
    AND a.house_number = g.house_number
WHERE g.egaid IS NOT NULL
GROUP BY g.egaid
HAVING COUNT(g.egaid) = 1;

