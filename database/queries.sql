-- Inventory counts by blood type.
SELECT
    blood_type,
    COUNT(*) AS available_units
FROM blood_units
WHERE status = 'available'
  AND expiry_date >= CURRENT_DATE
GROUP BY blood_type
ORDER BY blood_type;

-- Donor to blood unit: trace each inventory unit back to the donor.
SELECT
    d.donor_id,
    d.first_name || ' ' || d.last_name AS donor_name,
    d.blood_type AS donor_blood_type,
    bu.unit_code,
    bu.status,
    bu.collection_date,
    bu.expiry_date
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
JOIN blood_units bu ON dn.donation_id = bu.donation_id
ORDER BY bu.collection_date DESC;

-- Recipient to request: see what each recipient has requested.
SELECT
    r.recipient_id,
    r.first_name || ' ' || r.last_name AS recipient_name,
    r.blood_type AS recipient_blood_type,
    br.request_id,
    br.blood_type_needed,
    br.units_requested,
    br.urgency,
    br.status
FROM recipients r
JOIN blood_requests br ON r.recipient_id = br.recipient_id
ORDER BY br.request_date DESC;

-- Hospital to request: review demand by hospital.
SELECT
    h.hospital_id,
    h.hospital_name,
    h.city,
    h.state,
    br.request_id,
    br.blood_type_needed,
    br.units_requested,
    br.urgency,
    br.status
FROM hospitals h
JOIN blood_requests br ON h.hospital_id = br.hospital_id
ORDER BY h.hospital_name, br.request_date DESC;

-- Request to matched blood unit: units recorded after a request is fulfilled.
SELECT
    br.request_id,
    br.status AS request_status,
    r.first_name || ' ' || r.last_name AS recipient_name,
    r.blood_type AS recipient_blood_type,
    bu.unit_code,
    bu.blood_type AS unit_blood_type,
    bru.matched_at
FROM blood_requests br
JOIN recipients r ON br.recipient_id = r.recipient_id
JOIN blood_request_units bru ON br.request_id = bru.request_id
JOIN blood_units bu ON bru.unit_id = bu.unit_id
ORDER BY br.request_id, bu.unit_code;

-- Compatible available units for a pending request.
SELECT
    br.request_id,
    br.blood_type_needed,
    bu.unit_code,
    bu.blood_type AS compatible_unit_type,
    bu.expiry_date,
    bu.storage_location
FROM blood_requests br
JOIN blood_units bu
  ON is_blood_compatible(bu.blood_type, br.blood_type_needed)
WHERE br.status = 'pending'
  AND bu.status = 'available'
  AND bu.expiry_date >= CURRENT_DATE
ORDER BY br.request_id, bu.expiry_date;

-- Stored function: available units for one blood type.
SELECT *
FROM get_available_units_by_blood_type('O-');

-- Stored function: compatible donor blood types for a recipient blood type.
SELECT *
FROM get_compatible_blood_types('A+');

-- Stored function: available compatible units for one recipient.
SELECT *
FROM find_matching_units_for_recipient(1);

-- Stored procedure: fulfill a request with one selected compatible unit.
-- Run inside a transaction while testing so you can roll it back if needed.
BEGIN;
CALL fulfill_blood_request(1, 1);
SELECT *
FROM blood_request_units
WHERE request_id = 1;
ROLLBACK;

-- Recent inventory log entries.
SELECT
    il.created_at,
    il.action,
    bu.unit_code,
    il.old_status,
    il.new_status,
    il.changed_by,
    il.log_message
FROM inventory_logs il
LEFT JOIN blood_units bu ON il.unit_id = bu.unit_id
ORDER BY il.created_at DESC
LIMIT 25;
