# Blood Bank Management System

A small PostgreSQL and Streamlit project for managing donors, recipients, hospitals, blood units, and hospital blood requests.

I made this project to practice relational database design in a realistic workflow. The main focus is the database: normalized tables, constraints, indexes, joins, functions, seed data, and a simple UI that proves the schema works.

## What This Project Covers

- Normalized PostgreSQL schema for donors, donations, blood units, recipients, hospitals, requests, matched units, and inventory logs
- Primary keys, foreign keys, check constraints, unique constraints, and date checks
- Useful indexes for inventory, request, donor, recipient, and join queries
- PostgreSQL functions and procedures for blood compatibility, inventory lookup, matching, request fulfillment, and audit logs
- CSV seed data with fake sample records
- Python scripts for database setup and seeding
- Streamlit pages for dashboard metrics, donors, recipients, inventory, requests, and matching
- Basic pytest checks for helper logic and seed data quality

## Tech Stack

- PostgreSQL
- Python 3.10+
- Streamlit
- psycopg2
- pandas
- Docker Compose
- pytest

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
│   ├── queries.sql
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

The schema is split into separate tables so the same information is not stored in multiple places.

- `donors`: donor profile and blood type
- `donations`: donation events tied to donors
- `blood_units`: inventory units created from donations
- `recipients`: recipient profile and blood type
- `hospitals`: hospitals that make requests
- `blood_requests`: request records from hospitals for recipients
- `blood_request_units`: join table that records which units were matched or used for a request
- `inventory_logs`: audit trail for inventory status changes

This keeps the flow traceable:

```text
donor -> donation -> blood_unit -> blood_request_units -> blood_request -> recipient / hospital
```

## Setup

Start PostgreSQL:

```bash
docker-compose up -d
```

Create a local `.env` file:

```bash
cp .env.example .env
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Create the database tables, indexes, and functions:

```bash
python scripts/setup_database.py
```

Load the CSV sample data:

```bash
python scripts/seed_database.py
```

Run the app:

```bash
streamlit run app.py
```

The sidebar includes pages for Dashboard, Donors, Recipients, Blood Inventory, Blood Requests, and Match Blood Units.

## Stored Functions and Procedure

Most of the blood bank workflow is handled in PostgreSQL instead of being hidden in Python code.

- `get_available_units_by_blood_type(input_blood_type)` returns available units for one blood type with donor name, collection date, expiration date, and status.
- `get_compatible_blood_types(recipient_blood_type)` returns donor blood types that can be given to a recipient blood type.
- `find_matching_units_for_recipient(recipient_id)` returns available units that match one recipient.
- `fulfill_blood_request(request_id, blood_unit_id)` is a stored procedure that marks a request as fulfilled, marks the selected unit as used, records the request/unit match, and writes an inventory log row.
- `add_inventory_log(...)` is a helper function used by the fulfillment workflow.

The app uses these database routines in the Matching and Requests pages. The Matching page calls `find_matching_units_for_recipient`, and the Requests page calls `fulfill_blood_request` after a compatible unit is selected.

## Demo SQL

The file `database/queries.sql` has ready-to-run SQL examples for:

- inventory counts by blood type
- donor to blood unit joins
- recipient to request joins
- hospital to request joins
- request to matched blood unit joins
- compatible unit lookup for pending requests
- recent inventory log review
- stored function and procedure examples

Example:

```sql
SELECT
    d.first_name || ' ' || d.last_name AS donor_name,
    bu.unit_code,
    bu.blood_type,
    bu.status
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
JOIN blood_units bu ON dn.donation_id = bu.donation_id
ORDER BY bu.collection_date DESC;
```

## Tests

```bash
pytest
```

The tests check the blood compatibility helper and basic seed data consistency.

## Notes

All records are fake sample data. The project does not include authentication or deployment because the goal is to keep the database workflow clear and easy to run locally.

Possible improvements:

- Add reports for low-stock blood types
- Add donor appointment scheduling
- Track separate blood components such as plasma and platelets
- Add integration tests that run against the Docker database
