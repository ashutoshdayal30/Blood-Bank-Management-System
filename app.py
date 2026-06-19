import altair as alt
import pandas as pd
import streamlit as st

from src.blood_compatibility import BLOOD_TYPES
from src.db import execute, query_df


st.set_page_config(
    page_title="Blood Bank Management System",
    layout="wide",
)


GENDERS = ["Female", "Male", "Non-binary", "Prefer not to say"]
URGENCY_LEVELS = ["routine", "urgent", "critical"]


def apply_page_styles() -> None:
    st.markdown(
        """
        <style>
        .block-container {
            padding-top: 1.4rem;
            padding-bottom: 2rem;
            max-width: 1180px;
        }
        .stApp {
            background: #f7fafc;
            color: #1f2937;
        }
        [data-testid="stSidebar"] {
            background: #ffffff;
            border-right: 1px solid #e5e7eb;
        }
        [data-testid="stSidebar"] * {
            color: #1f2937 !important;
        }
        h1, h2, h3, p, label, span {
            color: #1f2937 !important;
        }
        div[data-testid="stMetric"] {
            background: #ffffff;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 14px 16px;
            box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
        }
        div[data-testid="stMetric"] * {
            color: #1f2937 !important;
        }
        div.stButton > button {
            border-radius: 6px;
            border-color: #b91c1c;
            color: #b91c1c;
            background: #ffffff;
        }
        .section-note {
            color: #64748b !important;
            font-size: 0.95rem;
            margin-bottom: 1rem;
        }
        table.clean-table {
            width: 100%;
            border-collapse: collapse;
            background: #ffffff;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            overflow: hidden;
            font-size: 0.92rem;
        }
        table.clean-table th {
            text-align: left;
            background: #f1f5f9;
            color: #334155;
            padding: 10px;
            border-bottom: 1px solid #e5e7eb;
            white-space: nowrap;
        }
        table.clean-table td {
            color: #1f2937;
            padding: 10px;
            border-bottom: 1px solid #edf2f7;
            white-space: nowrap;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def clean_text(value: str):
    value = value.strip()
    return value if value else None


def render_html_table(df: pd.DataFrame) -> None:
    st.markdown(
        df.to_html(index=False, classes="clean-table", border=0),
        unsafe_allow_html=True,
    )


def load_recipients() -> pd.DataFrame:
    return query_df(
        """
        SELECT recipient_id, first_name, last_name, blood_type
        FROM recipients
        ORDER BY last_name, first_name;
        """
    )


def load_hospitals() -> pd.DataFrame:
    return query_df(
        """
        SELECT hospital_id, hospital_name
        FROM hospitals
        ORDER BY hospital_name;
        """
    )


def show_dashboard() -> None:
    st.subheader("Inventory overview")
    st.markdown(
        "<div class='section-note'>A quick check of available units and open request volume.</div>",
        unsafe_allow_html=True,
    )

    inventory = query_df(
        """
        SELECT blood_type, COUNT(*) AS available_units
        FROM blood_units
        WHERE status = 'available'
          AND expiry_date >= CURRENT_DATE
        GROUP BY blood_type
        ORDER BY blood_type;
        """
    )

    requests = query_df(
        """
        SELECT status, COUNT(*) AS total_requests
        FROM blood_requests
        GROUP BY status
        ORDER BY status;
        """
    )

    expiring_soon = query_df(
        """
        SELECT unit_code, blood_type, expiry_date, storage_location
        FROM blood_units
        WHERE status = 'available'
          AND expiry_date >= CURRENT_DATE
        ORDER BY expiry_date, unit_code
        LIMIT 5;
        """
    )

    total_available = int(inventory["available_units"].sum()) if not inventory.empty else 0
    pending_requests = 0
    if not requests.empty and "pending" in requests["status"].values:
        pending_requests = int(requests.loc[requests["status"] == "pending", "total_requests"].iloc[0])

    col1, col2, col3 = st.columns(3)
    col1.metric("Available units", total_available)
    col2.metric("Pending requests", pending_requests)
    col3.metric("Blood types stocked", len(inventory))

    chart_col, table_col = st.columns([1.2, 1])
    chart_col.write("Available units by blood type")
    if inventory.empty:
        chart_col.info("No available units found.")
    else:
        chart = (
            alt.Chart(inventory)
            .mark_bar(color="#b91c1c", cornerRadiusTopLeft=4, cornerRadiusTopRight=4)
            .encode(
                x=alt.X("blood_type:N", title="Blood type", sort=None),
                y=alt.Y("available_units:Q", title="Available units"),
                tooltip=["blood_type", "available_units"],
            )
            .properties(height=320)
            .configure_view(strokeWidth=0)
            .configure(background="#ffffff")
            .configure_axis(labelColor="#334155", titleColor="#334155", gridColor="#e5e7eb")
        )
        chart_col.altair_chart(chart, use_container_width=True)

    table_col.write("Oldest available units")
    if expiring_soon.empty:
        table_col.info("No available units found.")
    else:
        with table_col:
            render_html_table(expiring_soon)


def show_donors() -> None:
    st.subheader("Donor registry")

    donors = query_df(
        """
        SELECT donor_id, first_name, last_name, blood_type, phone, email, city, state, registered_at
        FROM donors
        ORDER BY donor_id DESC;
        """
    )
    st.dataframe(donors, use_container_width=True, hide_index=True)

    with st.form("add_donor_form", clear_on_submit=True):
        st.write("Add a donor")
        col1, col2, col3 = st.columns(3)
        first_name = col1.text_input("First name")
        last_name = col2.text_input("Last name")
        blood_type = col3.selectbox("Blood type", BLOOD_TYPES)

        col4, col5, col6 = st.columns(3)
        phone = col4.text_input("Phone")
        email = col5.text_input("Email")
        date_of_birth = col6.date_input("Date of birth")

        col7, col8, col9 = st.columns(3)
        gender = col7.selectbox("Gender", GENDERS)
        city = col8.text_input("City")
        state = col9.text_input("State", value="AZ")

        submitted = st.form_submit_button("Add donor")
        if submitted:
            if not first_name.strip() or not last_name.strip():
                st.error("First name and last name are required.")
            else:
                execute(
                    """
                    INSERT INTO donors (
                        first_name, last_name, blood_type, phone, email,
                        date_of_birth, gender, city, state
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
                    """,
                    (
                        first_name.strip(),
                        last_name.strip(),
                        blood_type,
                        clean_text(phone),
                        clean_text(email),
                        date_of_birth,
                        gender,
                        clean_text(city),
                        clean_text(state),
                    ),
                )
                st.success("Donor added.")
                st.rerun()


def show_recipients() -> None:
    st.subheader("Recipient registry")

    recipients = query_df(
        """
        SELECT recipient_id, first_name, last_name, blood_type, phone, email, city, state, registered_at
        FROM recipients
        ORDER BY recipient_id DESC;
        """
    )
    st.dataframe(recipients, use_container_width=True, hide_index=True)

    with st.form("add_recipient_form", clear_on_submit=True):
        st.write("Add a recipient")
        col1, col2, col3 = st.columns(3)
        first_name = col1.text_input("First name")
        last_name = col2.text_input("Last name")
        blood_type = col3.selectbox("Blood type", BLOOD_TYPES)

        col4, col5, col6 = st.columns(3)
        phone = col4.text_input("Phone")
        email = col5.text_input("Email")
        date_of_birth = col6.date_input("Date of birth")

        col7, col8, col9 = st.columns(3)
        gender = col7.selectbox("Gender", GENDERS)
        city = col8.text_input("City")
        state = col9.text_input("State", value="AZ")

        submitted = st.form_submit_button("Add recipient")
        if submitted:
            if not first_name.strip() or not last_name.strip():
                st.error("First name and last name are required.")
            else:
                execute(
                    """
                    INSERT INTO recipients (
                        first_name, last_name, blood_type, phone, email,
                        date_of_birth, gender, city, state
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
                    """,
                    (
                        first_name.strip(),
                        last_name.strip(),
                        blood_type,
                        clean_text(phone),
                        clean_text(email),
                        date_of_birth,
                        gender,
                        clean_text(city),
                        clean_text(state),
                    ),
                )
                st.success("Recipient added.")
                st.rerun()


def show_inventory() -> None:
    st.subheader("Blood inventory")

    status_filter = st.selectbox(
        "Status",
        ["available", "reserved", "used", "expired", "all"],
    )
    params = []
    where_clause = ""
    if status_filter != "all":
        where_clause = "WHERE bu.status = %s"
        params.append(status_filter)

    inventory = query_df(
        f"""
        SELECT
            bu.unit_id,
            bu.unit_code,
            bu.blood_type,
            bu.status,
            bu.collection_date,
            bu.expiry_date,
            bu.storage_location,
            d.donation_date,
            dn.first_name || ' ' || dn.last_name AS donor_name
        FROM blood_units bu
        JOIN donations d ON bu.donation_id = d.donation_id
        JOIN donors dn ON d.donor_id = dn.donor_id
        {where_clause}
        ORDER BY bu.expiry_date, bu.unit_code;
        """,
        params,
    )
    st.dataframe(inventory, use_container_width=True, hide_index=True)


def show_requests() -> None:
    st.subheader("Hospital requests")

    recipients = load_recipients()
    hospitals = load_hospitals()

    with st.form("create_request_form", clear_on_submit=True):
        st.write("Create a request")
        col1, col2, col3, col4 = st.columns(4)

        recipient_options = {
            f"{row.first_name} {row.last_name} ({row.blood_type})": int(row.recipient_id)
            for row in recipients.itertuples()
        }
        hospital_options = {
            row.hospital_name: int(row.hospital_id)
            for row in hospitals.itertuples()
        }

        recipient_label = col1.selectbox("Recipient", list(recipient_options.keys()))
        hospital_label = col2.selectbox("Hospital", list(hospital_options.keys()))
        units_requested = col3.number_input("Units", min_value=1, max_value=10, value=1)
        urgency = col4.selectbox("Urgency", URGENCY_LEVELS)

        submitted = st.form_submit_button("Create request")
        if submitted:
            recipient_id = recipient_options[recipient_label]
            recipient_blood_type = recipients.loc[
                recipients["recipient_id"] == recipient_id, "blood_type"
            ].iloc[0]
            execute(
                """
                INSERT INTO blood_requests (
                    recipient_id, hospital_id, blood_type_needed,
                    units_requested, urgency, status
                )
                VALUES (%s, %s, %s, %s, %s, 'pending');
                """,
                (
                    recipient_id,
                    hospital_options[hospital_label],
                    recipient_blood_type,
                    int(units_requested),
                    urgency,
                ),
            )
            st.success("Request created.")
            st.rerun()

    requests = query_df(
        """
        SELECT
            br.request_id,
            r.first_name || ' ' || r.last_name AS recipient,
            h.hospital_name,
            br.blood_type_needed,
            br.units_requested,
            br.urgency,
            br.status,
            br.request_date,
            br.fulfilled_at
        FROM blood_requests br
        JOIN recipients r ON br.recipient_id = r.recipient_id
        JOIN hospitals h ON br.hospital_id = h.hospital_id
        ORDER BY br.request_date DESC;
        """
    )
    st.dataframe(requests, use_container_width=True, hide_index=True)

    pending = requests[requests["status"] == "pending"] if not requests.empty else pd.DataFrame()
    if not pending.empty:
        st.write("Fulfill a pending request")
        request_id = st.selectbox("Request ID", pending["request_id"].tolist())
        if st.button("Fulfill request"):
            try:
                used_units = query_df(
                    "SELECT * FROM fulfill_blood_request(%s, %s);",
                    (int(request_id), "Streamlit app"),
                )
                st.success(f"Request #{request_id} fulfilled.")
                st.dataframe(used_units, use_container_width=True, hide_index=True)
                st.rerun()
            except Exception as exc:
                st.error(str(exc))


def show_matching() -> None:
    st.subheader("Compatibility search")

    recipients = load_recipients()
    recipient_options = {
        f"{row.first_name} {row.last_name} ({row.blood_type})": int(row.recipient_id)
        for row in recipients.itertuples()
    }
    recipient_label = st.selectbox("Recipient", list(recipient_options.keys()))

    if st.button("Find compatible units"):
        matches = query_df(
            "SELECT * FROM compatible_units_for_recipient(%s);",
            (recipient_options[recipient_label],),
        )
        if matches.empty:
            st.info("No compatible available units found for this recipient.")
        else:
            st.dataframe(matches, use_container_width=True, hide_index=True)


def main() -> None:
    apply_page_styles()
    st.title("Blood Bank Operations")
    st.caption("PostgreSQL inventory tracking, request handling, and compatibility matching.")

    page = st.sidebar.radio(
        "Navigation",
        ["Dashboard", "Donors", "Recipients", "Blood Inventory", "Requests", "Matching"],
    )

    try:
        if page == "Dashboard":
            show_dashboard()
        elif page == "Donors":
            show_donors()
        elif page == "Recipients":
            show_recipients()
        elif page == "Blood Inventory":
            show_inventory()
        elif page == "Requests":
            show_requests()
        elif page == "Matching":
            show_matching()
    except Exception as exc:
        st.error("The app could not reach the database or run the query.")
        st.code(str(exc))
        st.info("Check that Docker is running and that setup_database.py has been run.")


if __name__ == "__main__":
    main()
