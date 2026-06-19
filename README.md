# Blood Bank Management System

Built by Ashutosh.

This is a beginner-to-new-grad level database project that models the basic work of a local blood bank. The project uses PostgreSQL for the relational database, Python for setup and seed scripts, and Streamlit for a small dashboard-style UI.

The main goal is to show clean SQL fundamentals: normalized tables, primary and foreign keys, constraints, indexes, joins, CSV seed data, and PostgreSQL functions that handle common blood bank actions.

## Features

- PostgreSQL schema for donors, recipients, hospitals, donations, blood units, blood requests, and inventory logs
- Fake CSV seed data for a realistic local dataset
- Python scripts to create the database objects and load the seed data
- Streamlit dashboard for inventory, donors, recipients, requests, and matching
- PostgreSQL functions for blood type compatibility, inventory lookup, request fulfillment, and inventory logging
- Basic pytest tests for compatibility rules and seed file quality
- Docker Compose setup for running PostgreSQL locally

## Project Structure

```text
.
├── app.py
├── data/
│   ├── blood_requests.csv
│   ├── blood_units.csv
│   ├── donors.csv
│   ├── hospitals.csv
│   └── recipients.csv
├── database/
│   ├── functions.sql
│   ├── indexes.sql
│   ├── schema.sql
│   └── seed.sql
├── scripts/
│   ├── seed_database.py
│   └── setup_database.py
├── src/
│   ├── blood_compatibility.py
│   └── db.py
├── tests/
│   ├── test_blood_compatibility.py
│   └── test_seed_files.py
├── docker-compose.yml
├── requirements.txt
└── .env.example
```

## Database Design

The schema is normalized around the main entities in a small blood bank workflow.

- `donors` stores donor contact and blood type details.
- `donations` stores each donation event and links back to one donor.
- `blood_units` stores individual units created from donations.
- `recipients` stores people who may receive blood.
- `hospitals` stores hospital details.
- `blood_requests` connects recipients and hospitals when blood is requested.
- `inventory_logs` records important inventory changes, such as a unit being added or issued.

The design avoids storing the same relationship in multiple places. For example, a blood unit points to a donation, and the donation points to the donor. That keeps donor information in one place while still making it easy to join from a unit back to the donor.

## Database Functions

The project includes PostgreSQL functions in `database/functions.sql`:

- `is_blood_compatible(donor_blood_type, recipient_blood_type)`
- `available_blood_units_by_type(p_blood_type)`
- `compatible_units_for_recipient(p_recipient_id)`
- `fulfill_blood_request(p_request_id, p_changed_by)`
- `add_inventory_log(...)`

The request fulfillment function updates blood unit status, marks the request as fulfilled, and writes inventory log rows in one database transaction.

## Setup

### 1. Start PostgreSQL

```bash
docker-compose up -d
```

### 2. Create a local environment file

```bash
cp .env.example .env
```

The default values match the PostgreSQL container in `docker-compose.yml`.

### 3. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 4. Create tables, indexes, and functions

```bash
python scripts/setup_database.py
```

### 5. Load CSV seed data

```bash
python scripts/seed_database.py
```

### 6. Run the Streamlit app

```bash
streamlit run app.py
```

## Expected Run Commands

These are the main commands for a fresh local run:

```bash
docker-compose up -d
pip install -r requirements.txt
python scripts/setup_database.py
python scripts/seed_database.py
streamlit run app.py
```

## Running Tests

```bash
pytest
```

The current tests are intentionally lightweight. They check the blood compatibility helper and verify that the seed CSV files are present and internally consistent.

## Sample SQL Queries

Inventory count by blood type:

```sql
SELECT blood_type, COUNT(*) AS available_units
FROM blood_units
WHERE status = 'available'
  AND expiry_date >= CURRENT_DATE
GROUP BY blood_type
ORDER BY blood_type;
```

Open requests with hospital and recipient details:

```sql
SELECT
    br.request_id,
    r.first_name || ' ' || r.last_name AS recipient_name,
    h.hospital_name,
    br.blood_type_needed,
    br.units_requested,
    br.urgency,
    br.status
FROM blood_requests br
JOIN recipients r ON br.recipient_id = r.recipient_id
JOIN hospitals h ON br.hospital_id = h.hospital_id
WHERE br.status = 'pending'
ORDER BY br.request_date DESC;
```

Compatible available units for one recipient:

```sql
SELECT *
FROM compatible_units_for_recipient(1);
```

Fulfill a blood request:

```sql
SELECT *
FROM fulfill_blood_request(1, 'manual SQL check');
```

View recent inventory activity:

```sql
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
LIMIT 20;
```

## Notes About the Sample Data

All names, phone numbers, emails, hospitals, and addresses are fake sample data. They are only here to make the database and dashboard feel realistic while staying safe for a public GitHub project.

## Future Improvements

- Add role-based access for staff users
- Add appointment scheduling for donors
- Track blood component types such as plasma, platelets, and red cells
- Add charts for monthly donations and request trends
- Add a small reporting page for low-stock blood types
- Add integration tests that run against the Docker PostgreSQL container
