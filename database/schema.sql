DROP TABLE IF EXISTS inventory_logs CASCADE;
DROP TABLE IF EXISTS blood_request_units CASCADE;
DROP TABLE IF EXISTS blood_requests CASCADE;
DROP TABLE IF EXISTS blood_units CASCADE;
DROP TABLE IF EXISTS donations CASCADE;
DROP TABLE IF EXISTS recipients CASCADE;
DROP TABLE IF EXISTS hospitals CASCADE;
DROP TABLE IF EXISTS donors CASCADE;

CREATE TABLE donors (
    donor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    blood_type VARCHAR(3) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(120) UNIQUE,
    date_of_birth DATE NOT NULL,
    gender VARCHAR(20),
    city VARCHAR(80),
    state VARCHAR(40),
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT donors_blood_type_check CHECK (
        blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),
    CONSTRAINT donors_gender_check CHECK (
        gender IS NULL OR gender IN ('Female', 'Male', 'Non-binary', 'Prefer not to say')
    ),
    CONSTRAINT donors_birth_date_check CHECK (
        date_of_birth < CURRENT_DATE
    )
);

COMMENT ON TABLE donors IS 'People registered as blood donors. One donor can have many donation records.';

CREATE TABLE hospitals (
    hospital_id SERIAL PRIMARY KEY,
    hospital_name VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20),
    city VARCHAR(80) NOT NULL,
    state VARCHAR(40) NOT NULL,
    address_line VARCHAR(160),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE hospitals IS 'Hospitals that place blood requests for recipients.';

CREATE TABLE recipients (
    recipient_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    blood_type VARCHAR(3) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(120) UNIQUE,
    date_of_birth DATE NOT NULL,
    gender VARCHAR(20),
    city VARCHAR(80),
    state VARCHAR(40),
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT recipients_blood_type_check CHECK (
        blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),
    CONSTRAINT recipients_gender_check CHECK (
        gender IS NULL OR gender IN ('Female', 'Male', 'Non-binary', 'Prefer not to say')
    ),
    CONSTRAINT recipients_birth_date_check CHECK (
        date_of_birth < CURRENT_DATE
    )
);

COMMENT ON TABLE recipients IS 'People who may receive blood units through hospital requests.';

CREATE TABLE donations (
    donation_id SERIAL PRIMARY KEY,
    donor_id INTEGER NOT NULL REFERENCES donors(donor_id) ON DELETE RESTRICT,
    donation_date DATE NOT NULL,
    volume_ml INTEGER NOT NULL DEFAULT 450,
    collection_site VARCHAR(120) NOT NULL DEFAULT 'Main Blood Center',
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT donations_volume_check CHECK (volume_ml BETWEEN 300 AND 550),
    CONSTRAINT donations_date_check CHECK (donation_date <= CURRENT_DATE)
);

COMMENT ON TABLE donations IS 'Donation events. Each donation belongs to one donor and can produce one blood unit in this project.';

CREATE TABLE blood_units (
    unit_id SERIAL PRIMARY KEY,
    donation_id INTEGER NOT NULL REFERENCES donations(donation_id) ON DELETE RESTRICT,
    unit_code VARCHAR(30) NOT NULL UNIQUE,
    blood_type VARCHAR(3) NOT NULL,
    collection_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'available',
    storage_location VARCHAR(80) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT blood_units_blood_type_check CHECK (
        blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),
    CONSTRAINT blood_units_status_check CHECK (
        status IN ('available', 'reserved', 'used', 'expired')
    ),
    CONSTRAINT blood_units_expiry_check CHECK (expiry_date > collection_date),
    CONSTRAINT blood_units_collection_check CHECK (collection_date <= CURRENT_DATE)
);

COMMENT ON TABLE blood_units IS 'Individual blood units in inventory. Each unit is traced back to a donation.';

CREATE TABLE blood_requests (
    request_id SERIAL PRIMARY KEY,
    recipient_id INTEGER NOT NULL REFERENCES recipients(recipient_id) ON DELETE RESTRICT,
    hospital_id INTEGER NOT NULL REFERENCES hospitals(hospital_id) ON DELETE RESTRICT,
    blood_type_needed VARCHAR(3) NOT NULL,
    units_requested INTEGER NOT NULL,
    urgency VARCHAR(20) NOT NULL DEFAULT 'routine',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    request_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at TIMESTAMP,
    CONSTRAINT requests_blood_type_check CHECK (
        blood_type_needed IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),
    CONSTRAINT requests_units_check CHECK (units_requested > 0),
    CONSTRAINT requests_urgency_check CHECK (
        urgency IN ('routine', 'urgent', 'critical')
    ),
    CONSTRAINT requests_status_check CHECK (
        status IN ('pending', 'fulfilled', 'cancelled')
    ),
    CONSTRAINT requests_fulfilled_date_check CHECK (
        fulfilled_at IS NULL OR fulfilled_at >= request_date
    )
);

COMMENT ON TABLE blood_requests IS 'Requests from hospitals for blood units needed by recipients.';

CREATE TABLE blood_request_units (
    request_unit_id SERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES blood_requests(request_id) ON DELETE CASCADE,
    unit_id INTEGER NOT NULL REFERENCES blood_units(unit_id) ON DELETE RESTRICT,
    matched_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT request_unit_unique_check UNIQUE (request_id, unit_id)
);

COMMENT ON TABLE blood_request_units IS 'Join table that records which blood units were matched or used for each request.';

CREATE TABLE inventory_logs (
    log_id SERIAL PRIMARY KEY,
    unit_id INTEGER REFERENCES blood_units(unit_id) ON DELETE SET NULL,
    request_id INTEGER REFERENCES blood_requests(request_id) ON DELETE SET NULL,
    action VARCHAR(30) NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_by VARCHAR(80) NOT NULL DEFAULT 'system',
    log_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inventory_logs_action_check CHECK (
        action IN ('added', 'reserved', 'used', 'expired', 'adjusted')
    )
);

COMMENT ON TABLE inventory_logs IS 'Audit trail for important inventory status changes.';
