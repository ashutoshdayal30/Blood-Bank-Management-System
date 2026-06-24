-- Inventory by blood type.
SELECT
    blood_type,
    COUNT(*) AS available_units
FROM blood_units
WHERE status = 'available'
  AND expiry_date >= CURRENT_DATE
GROUP BY blood_type
ORDER BY blood_type;

-- Available blood units with donor details.
SELECT
    bu.unit_id,
    bu.unit_code,
    bu.blood_type,
    bu.collection_date,
    bu.expiry_date,
    bu.storage_location,
    d.first_name || ' ' || d.last_name AS donor_name
FROM blood_units bu
JOIN donations dn ON bu.donation_id = dn.donation_id
JOIN donors d ON dn.donor_id = d.donor_id
WHERE bu.status = 'available'
  AND bu.expiry_date >= CURRENT_DATE
ORDER BY bu.expiry_date, bu.unit_code;

-- Donor to blood unit join.
SELECT
    d.donor_id,
    d.first_name || ' ' || d.last_name AS donor_name,
    d.blood_type AS donor_blood_type,
    dn.donation_date,
    bu.unit_code,
    bu.status,
    bu.expiry_date
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
JOIN blood_units bu ON dn.donation_id = bu.donation_id
ORDER BY dn.donation_date DESC, bu.unit_code;

-- Recipient to request join.
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

-- Hospital to request join.
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

-- Compatible blood unit matching for one recipient.
SELECT *
FROM find_matching_units_for_recipient(1);

-- Compatible donor blood types for a recipient blood type.
SELECT *
FROM get_compatible_blood_types('A+');

-- Available units for one blood type.
SELECT *
FROM get_available_units_by_blood_type('O-');

-- Request fulfillment history.
SELECT
    br.request_id,
    br.status AS request_status,
    br.fulfilled_at,
    r.first_name || ' ' || r.last_name AS recipient_name,
    h.hospital_name,
    bu.unit_code,
    bu.blood_type AS used_unit_blood_type,
    bru.matched_at
FROM blood_requests br
JOIN recipients r ON br.recipient_id = r.recipient_id
JOIN hospitals h ON br.hospital_id = h.hospital_id
JOIN blood_request_units bru ON br.request_id = bru.request_id
JOIN blood_units bu ON bru.unit_id = bu.unit_id
ORDER BY br.fulfilled_at DESC, br.request_id DESC;

-- Inventory log history.
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

-- Safe way to test request fulfillment and roll it back.
BEGIN;
CALL fulfill_blood_request(1, 1);
SELECT *
FROM blood_request_units
WHERE request_id = 1;
ROLLBACK;
