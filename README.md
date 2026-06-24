# Blood Bank Management System

A PostgreSQL-backed blood bank inventory and request management system built with Python and Streamlit.

This project models a small blood bank workflow: donors give blood, blood units are added to inventory, hospitals create requests for recipients, and compatible units are matched and marked as used. The main focus is the database design and SQL workflow, with Streamlit providing a simple interface to use the system.

## Features

- Donor and recipient management
- Blood inventory tracking
- Blood request workflow
- Compatible blood matching
- PostgreSQL stored procedures/functions
- Indexed and normalized relational database
- CSV-based seed data
- Streamlit dashboard

## Tech Stack

- Python
- PostgreSQL
- Streamlit
- SQL
- Docker
- pandas

## Database Design

The database is organized around the core parts of a blood bank system:

- `donors` stores donor profile details and blood type.
- `donations` records donation events and connects each donation to a donor.
- `blood_units` tracks individual units in inventory, including blood type, status, collection date, and expiration date.
- `recipients` stores recipient details and required blood type.
- `hospitals` stores hospitals that place blood requests.
- `blood_requests` records requests made for recipients through hospitals.
- `blood_request_units` links fulfilled requests to the specific blood units used.
- `inventory_logs` keeps a history of important inventory changes.

The main relationship flow is:

```text
donor -> donation -> blood_unit -> blood_request_units -> blood_request -> recipient / hospital
```

This keeps the data normalized while still making it easy to trace a used blood unit back to the donor, request, recipient, and hospital.

## Setup Instructions

Start PostgreSQL with Docker:

```bash
docker-compose up -d
```

Install Python dependencies:

```bash
pip install -r requirements.txt
```

Create the local environment file:

```bash
cp .env.example .env
```

Create the database schema, indexes, and stored functions:

```bash
python3 scripts/setup_database.py
```

Load sample CSV data:

```bash
python3 scripts/seed_database.py
```

Run the Streamlit app:

```bash
streamlit run app.py
```

## What This Project Demonstrates

This project is mainly meant to show practical SQL and relational database work:

- Relational database architecture using separate tables for donors, donations, inventory, recipients, hospitals, requests, and logs
- SQL queries and joins for donor-to-unit, recipient-to-request, hospital-to-request, and request-to-unit workflows
- Stored procedures/functions for blood compatibility, inventory lookup, matching, request fulfillment, and inventory logging
- Indexing for common lookup paths such as blood type, inventory status, request status, hospitals, recipients, and request-unit joins
- Normalized tables that avoid storing the same relationship in multiple places
- Real-time inventory lookup through the Streamlit app using PostgreSQL queries

## Stored Functions and Procedures

The database includes PostgreSQL routines for the main workflow:

- `get_available_units_by_blood_type(input_blood_type)`
- `get_compatible_blood_types(recipient_blood_type)`
- `find_matching_units_for_recipient(recipient_id)`
- `fulfill_blood_request(request_id, blood_unit_id)`
- `add_inventory_log(...)`

The app uses these routines in the blood matching and request fulfillment pages.

## Project Structure

```text
.
├── app.py
├── data/
├── database/
│   ├── schema.sql
│   ├── indexes.sql
│   ├── functions.sql
│   └── queries.sql
├── scripts/
├── src/
├── tests/
├── docker-compose.yml
├── requirements.txt
└── .env.example
```

## Testing

```bash
pytest
```

The tests cover blood compatibility logic and basic seed data checks.
