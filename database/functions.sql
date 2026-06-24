DROP FUNCTION IF EXISTS fulfill_blood_request(INTEGER, TEXT);
DROP PROCEDURE IF EXISTS fulfill_blood_request(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS find_matching_units_for_recipient(INTEGER);
DROP FUNCTION IF EXISTS get_compatible_blood_types(TEXT);
DROP FUNCTION IF EXISTS get_available_units_by_blood_type(TEXT);
DROP FUNCTION IF EXISTS compatible_units_for_recipient(INTEGER);
DROP FUNCTION IF EXISTS available_blood_units_by_type(TEXT);
DROP FUNCTION IF EXISTS add_inventory_log(INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS is_blood_compatible(TEXT, TEXT);

CREATE OR REPLACE FUNCTION is_blood_compatible(
    donor_blood_type TEXT,
    recipient_blood_type TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN CASE recipient_blood_type
        WHEN 'O-' THEN donor_blood_type IN ('O-')
        WHEN 'O+' THEN donor_blood_type IN ('O-', 'O+')
        WHEN 'A-' THEN donor_blood_type IN ('O-', 'A-')
        WHEN 'A+' THEN donor_blood_type IN ('O-', 'O+', 'A-', 'A+')
        WHEN 'B-' THEN donor_blood_type IN ('O-', 'B-')
        WHEN 'B+' THEN donor_blood_type IN ('O-', 'O+', 'B-', 'B+')
        WHEN 'AB-' THEN donor_blood_type IN ('O-', 'A-', 'B-', 'AB-')
        WHEN 'AB+' THEN donor_blood_type IN ('O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+')
        ELSE FALSE
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_compatible_blood_types(
    recipient_blood_type TEXT
)
RETURNS TABLE (
    compatible_blood_type TEXT
) AS $$
BEGIN
    IF recipient_blood_type IS NULL
       OR recipient_blood_type NOT IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-') THEN
        RAISE EXCEPTION 'Invalid recipient blood type: %', recipient_blood_type;
    END IF;

    RETURN QUERY
    SELECT compatible.donor_type
    FROM unnest(ARRAY['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+']) AS compatible(donor_type)
    WHERE is_blood_compatible(compatible.donor_type, recipient_blood_type)
    ORDER BY
        CASE compatible.donor_type
            WHEN 'O-' THEN 1
            WHEN 'O+' THEN 2
            WHEN 'A-' THEN 3
            WHEN 'A+' THEN 4
            WHEN 'B-' THEN 5
            WHEN 'B+' THEN 6
            WHEN 'AB-' THEN 7
            WHEN 'AB+' THEN 8
        END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION add_inventory_log(
    p_unit_id INTEGER,
    p_request_id INTEGER,
    p_action TEXT,
    p_old_status TEXT,
    p_new_status TEXT,
    p_changed_by TEXT,
    p_log_message TEXT
)
RETURNS INTEGER AS $$
DECLARE
    new_log_id INTEGER;
BEGIN
    INSERT INTO inventory_logs (
        unit_id,
        request_id,
        action,
        old_status,
        new_status,
        changed_by,
        log_message
    )
    VALUES (
        p_unit_id,
        p_request_id,
        p_action,
        p_old_status,
        p_new_status,
        COALESCE(NULLIF(p_changed_by, ''), 'system'),
        p_log_message
    )
    RETURNING log_id INTO new_log_id;

    RETURN new_log_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_available_units_by_blood_type(
    input_blood_type TEXT
)
RETURNS TABLE (
    unit_id INTEGER,
    unit_code VARCHAR,
    donor_name TEXT,
    blood_type VARCHAR,
    collection_date DATE,
    expiration_date DATE,
    status VARCHAR
) AS $$
BEGIN
    IF input_blood_type IS NULL
       OR input_blood_type NOT IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-') THEN
        RAISE EXCEPTION 'Invalid blood type: %', input_blood_type;
    END IF;

    RETURN QUERY
    SELECT
        bu.unit_id,
        bu.unit_code,
        d.first_name || ' ' || d.last_name AS donor_name,
        bu.blood_type,
        bu.collection_date,
        bu.expiry_date AS expiration_date,
        bu.status
    FROM blood_units bu
    JOIN donations dn ON bu.donation_id = dn.donation_id
    JOIN donors d ON dn.donor_id = d.donor_id
    WHERE bu.blood_type = input_blood_type
      AND bu.status = 'available'
      AND bu.expiry_date >= CURRENT_DATE
    ORDER BY bu.expiry_date, bu.unit_code;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION find_matching_units_for_recipient(
    p_recipient_id INTEGER
)
RETURNS TABLE (
    unit_id INTEGER,
    unit_code VARCHAR,
    donor_id INTEGER,
    donor_name TEXT,
    donor_blood_type VARCHAR,
    recipient_blood_type VARCHAR,
    collection_date DATE,
    expiry_date DATE,
    storage_location VARCHAR
) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM recipients WHERE recipients.recipient_id = p_recipient_id) THEN
        RAISE EXCEPTION 'Recipient % was not found.', p_recipient_id;
    END IF;

    RETURN QUERY
    SELECT
        bu.unit_id,
        bu.unit_code,
        d.donor_id,
        d.first_name || ' ' || d.last_name AS donor_name,
        bu.blood_type AS donor_blood_type,
        r.blood_type AS recipient_blood_type,
        bu.collection_date,
        bu.expiry_date,
        bu.storage_location
    FROM recipients r
    JOIN blood_units bu
      ON is_blood_compatible(bu.blood_type, r.blood_type)
    JOIN donations dn ON bu.donation_id = dn.donation_id
    JOIN donors d ON dn.donor_id = d.donor_id
    WHERE r.recipient_id = p_recipient_id
      AND bu.status = 'available'
      AND bu.expiry_date >= CURRENT_DATE
    ORDER BY bu.expiry_date, bu.unit_code;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE PROCEDURE fulfill_blood_request(
    p_request_id INT,
    p_blood_unit_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    request_row blood_requests%ROWTYPE;
    unit_row blood_units%ROWTYPE;
BEGIN
    SELECT *
    INTO request_row
    FROM blood_requests br
    WHERE br.request_id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blood request % was not found.', p_request_id;
    END IF;

    IF request_row.status <> 'pending' THEN
        RAISE EXCEPTION 'Blood request % is %, not pending.', p_request_id, request_row.status;
    END IF;

    SELECT *
    INTO unit_row
    FROM blood_units bu
    WHERE bu.unit_id = p_blood_unit_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blood unit % was not found.', p_blood_unit_id;
    END IF;

    IF unit_row.status <> 'available' THEN
        RAISE EXCEPTION 'Blood unit % is %, not available.', p_blood_unit_id, unit_row.status;
    END IF;

    IF unit_row.expiry_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Blood unit % expired on %.', p_blood_unit_id, unit_row.expiry_date;
    END IF;

    IF NOT is_blood_compatible(unit_row.blood_type, request_row.blood_type_needed) THEN
        RAISE EXCEPTION
            'Blood unit type % is not compatible with requested type %.',
            unit_row.blood_type,
            request_row.blood_type_needed;
    END IF;

    UPDATE blood_units
    SET status = 'used'
    WHERE unit_id = p_blood_unit_id;

    INSERT INTO blood_request_units (request_id, unit_id)
    VALUES (p_request_id, p_blood_unit_id);

    PERFORM add_inventory_log(
        p_blood_unit_id,
        p_request_id,
        'used',
        'available',
        'used',
        'Streamlit app',
        'Unit used for blood request #' || p_request_id
    );

    UPDATE blood_requests
    SET status = 'fulfilled',
        fulfilled_at = CURRENT_TIMESTAMP
    WHERE blood_requests.request_id = p_request_id;
END;
$$;
