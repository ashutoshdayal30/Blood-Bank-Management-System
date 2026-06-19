DROP FUNCTION IF EXISTS fulfill_blood_request(INTEGER, TEXT);
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

CREATE OR REPLACE FUNCTION available_blood_units_by_type(
    p_blood_type TEXT
)
RETURNS TABLE (
    blood_type VARCHAR,
    available_units BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bu.blood_type,
        COUNT(*) AS available_units
    FROM blood_units bu
    WHERE bu.status = 'available'
      AND bu.expiry_date >= CURRENT_DATE
      AND (p_blood_type IS NULL OR bu.blood_type = p_blood_type)
    GROUP BY bu.blood_type
    ORDER BY bu.blood_type;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION compatible_units_for_recipient(
    p_recipient_id INTEGER
)
RETURNS TABLE (
    unit_id INTEGER,
    unit_code VARCHAR,
    donor_blood_type VARCHAR,
    recipient_blood_type VARCHAR,
    expiry_date DATE,
    storage_location VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bu.unit_id,
        bu.unit_code,
        bu.blood_type AS donor_blood_type,
        r.blood_type AS recipient_blood_type,
        bu.expiry_date,
        bu.storage_location
    FROM recipients r
    JOIN blood_units bu
      ON is_blood_compatible(bu.blood_type, r.blood_type)
    WHERE r.recipient_id = p_recipient_id
      AND bu.status = 'available'
      AND bu.expiry_date >= CURRENT_DATE
    ORDER BY bu.expiry_date, bu.unit_code;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION fulfill_blood_request(
    p_request_id INTEGER,
    p_changed_by TEXT DEFAULT 'system'
)
RETURNS TABLE (
    used_unit_id INTEGER,
    used_unit_code VARCHAR
) AS $$
DECLARE
    request_row blood_requests%ROWTYPE;
    selected_unit RECORD;
    selected_count INTEGER;
BEGIN
    SELECT *
    INTO request_row
    FROM blood_requests
    WHERE request_id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blood request % was not found.', p_request_id;
    END IF;

    IF request_row.status <> 'pending' THEN
        RAISE EXCEPTION 'Blood request % is %, not pending.', p_request_id, request_row.status;
    END IF;

    SELECT COUNT(*)
    INTO selected_count
    FROM (
        SELECT bu.unit_id
        FROM blood_units bu
        WHERE bu.status = 'available'
          AND bu.expiry_date >= CURRENT_DATE
          AND is_blood_compatible(bu.blood_type, request_row.blood_type_needed)
        ORDER BY bu.expiry_date, bu.unit_id
        LIMIT request_row.units_requested
    ) available_units;

    IF selected_count < request_row.units_requested THEN
        RAISE EXCEPTION 'Not enough compatible units are available for request %.', p_request_id;
    END IF;

    FOR selected_unit IN
        SELECT bu.unit_id, bu.unit_code
        FROM blood_units bu
        WHERE bu.status = 'available'
          AND bu.expiry_date >= CURRENT_DATE
          AND is_blood_compatible(bu.blood_type, request_row.blood_type_needed)
        ORDER BY bu.expiry_date, bu.unit_id
        LIMIT request_row.units_requested
        FOR UPDATE
    LOOP
        UPDATE blood_units
        SET status = 'used'
        WHERE unit_id = selected_unit.unit_id;

        INSERT INTO blood_request_units (request_id, unit_id)
        VALUES (p_request_id, selected_unit.unit_id);

        PERFORM add_inventory_log(
            selected_unit.unit_id,
            p_request_id,
            'used',
            'available',
            'used',
            p_changed_by,
            'Unit used for blood request #' || p_request_id
        );

        used_unit_id := selected_unit.unit_id;
        used_unit_code := selected_unit.unit_code;
        RETURN NEXT;
    END LOOP;

    UPDATE blood_requests
    SET status = 'fulfilled',
        fulfilled_at = CURRENT_TIMESTAMP
    WHERE request_id = p_request_id;
END;
$$ LANGUAGE plpgsql;
