CREATE INDEX IF NOT EXISTS idx_donors_blood_type
    ON donors(blood_type);

CREATE INDEX IF NOT EXISTS idx_recipients_blood_type
    ON recipients(blood_type);

CREATE INDEX IF NOT EXISTS idx_hospitals_city_state
    ON hospitals(city, state);

CREATE INDEX IF NOT EXISTS idx_donations_donor_date
    ON donations(donor_id, donation_date DESC);

CREATE INDEX IF NOT EXISTS idx_blood_units_status_type
    ON blood_units(status, blood_type);

CREATE INDEX IF NOT EXISTS idx_blood_units_expiry_available
    ON blood_units(expiry_date)
    WHERE status = 'available';

CREATE INDEX IF NOT EXISTS idx_blood_requests_status_urgency
    ON blood_requests(status, urgency);

CREATE INDEX IF NOT EXISTS idx_blood_requests_recipient
    ON blood_requests(recipient_id);

CREATE INDEX IF NOT EXISTS idx_blood_requests_hospital
    ON blood_requests(hospital_id);

CREATE INDEX IF NOT EXISTS idx_blood_request_units_request
    ON blood_request_units(request_id);

CREATE INDEX IF NOT EXISTS idx_blood_request_units_unit
    ON blood_request_units(unit_id);

CREATE INDEX IF NOT EXISTS idx_inventory_logs_unit_date
    ON inventory_logs(unit_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_inventory_logs_request
    ON inventory_logs(request_id);
