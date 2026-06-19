from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"


def test_required_seed_files_exist_and_have_rows():
    file_names = [
        "donors.csv",
        "recipients.csv",
        "hospitals.csv",
        "blood_units.csv",
        "blood_requests.csv",
    ]

    for file_name in file_names:
        path = DATA_DIR / file_name
        assert path.exists(), f"{file_name} is missing"
        assert not pd.read_csv(path).empty, f"{file_name} should contain sample rows"


def test_blood_unit_expiry_dates_are_after_collection_dates():
    blood_units = pd.read_csv(DATA_DIR / "blood_units.csv", parse_dates=["collection_date", "expiry_date"])
    assert (blood_units["expiry_date"] > blood_units["collection_date"]).all()


def test_blood_requests_reference_seeded_recipients_and_hospitals():
    recipients = pd.read_csv(DATA_DIR / "recipients.csv")
    hospitals = pd.read_csv(DATA_DIR / "hospitals.csv")
    requests = pd.read_csv(DATA_DIR / "blood_requests.csv")

    assert set(requests["recipient_id"]).issubset(set(recipients["recipient_id"]))
    assert set(requests["hospital_id"]).issubset(set(hospitals["hospital_id"]))
