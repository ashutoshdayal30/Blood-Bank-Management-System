CREATE TABLE IF NOT EXISTS donors (
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
    )
);

CREATE TABLE IF NOT EXISTS hospitals (
    hospital_id SERIAL PRIMARY KEY,
    hospital_name VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20),
    city VARCHAR(80) NOT NULL,
    state VARCHAR(40) NOT NULL,
    address_line VARCHAR(160),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS recipients (
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
    )
);

CREATE TABLE IF NOT EXISTS donations (
    donation_id SERIAL PRIMARY KEY,
    donor_id INTEGER NOT NULL REFERENCES donors(donor_id) ON DELETE RESTRICT,
    donation_date DATE NOT NULL,
    volume_ml INTEGER NOT NULL DEFAULT 450,
    collection_site VARCHAR(120) NOT NULL DEFAULT 'Main Blood Center',
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT donations_volume_check CHECK (volume_ml BETWEEN 300 AND 550)
);

CREATE TABLE IF NOT EXISTS blood_units (
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
        status IN ('available', 'reserved', 'issued', 'expired', 'discarded')
    ),
    CONSTRAINT blood_units_expiry_check CHECK (expiry_date > collection_date)
);

CREATE TABLE IF NOT EXISTS blood_requests (
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
    )
);

CREATE TABLE IF NOT EXISTS inventory_logs (
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
        action IN ('added', 'reserved', 'issued', 'expired', 'discarded', 'adjusted')
    )
);
