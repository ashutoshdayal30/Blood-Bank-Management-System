BLOOD_TYPES = ["O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"]

COMPATIBLE_DONORS = {
    "O-": ["O-"],
    "O+": ["O-", "O+"],
    "A-": ["O-", "A-"],
    "A+": ["O-", "O+", "A-", "A+"],
    "B-": ["O-", "B-"],
    "B+": ["O-", "O+", "B-", "B+"],
    "AB-": ["O-", "A-", "B-", "AB-"],
    "AB+": ["O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"],
}


def is_compatible(donor_blood_type: str, recipient_blood_type: str) -> bool:
    """Return True when a donor unit can be given to a recipient."""
    return donor_blood_type in COMPATIBLE_DONORS.get(recipient_blood_type, [])
