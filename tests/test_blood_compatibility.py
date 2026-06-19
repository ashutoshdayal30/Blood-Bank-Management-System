from src.blood_compatibility import BLOOD_TYPES, is_compatible


def test_o_negative_is_universal_donor():
    for recipient_type in BLOOD_TYPES:
        assert is_compatible("O-", recipient_type)


def test_ab_positive_can_receive_every_type():
    for donor_type in BLOOD_TYPES:
        assert is_compatible(donor_type, "AB+")


def test_incompatible_pair_is_rejected():
    assert not is_compatible("AB+", "O+")
    assert not is_compatible("B+", "A+")
