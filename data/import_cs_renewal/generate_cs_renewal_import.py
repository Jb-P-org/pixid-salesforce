#!/usr/bin/env python3
"""
Generate CSV import files for Pack C&S Renewal from a semicolon-delimited CSV.

Creates 4 CSV files to be imported sequentially:
1. opportunities.csv       - One Opportunity (Renewal) per Account
2. opportunity_line_items.csv - One OLI per line (linked to Opportunity)
3. charge_maps.csv         - One ChargeMap per Account (linked to Opportunity)
4. charge_map_items.csv    - One ChargeMapItem per line (linked to ChargeMap)

CSV Column mapping (semicolon-delimited):
  0: Account ID
  1: Products ID (Product2 ID, 01t...)
  2: Article SF (product name)
  3: Line description
  4: Billing schedule
  5: Terme
  6: Billing start date (DD/MM/YYYY)
  7: End date (DD/MM/YYYY)
  8: Activity
  9: Offer
 10: Closing Date (DD/MM/YYYY)
 11: Invoice sending method
 12: Send invoice to
 13: Payment method
 14: Charge map type
 15: Billing instruction
 16: Billing conditions
 17: PO Required?
 18: PO Reference
 19: PO Request Date
 20: Billing Contact ID
 21: Cash collection ID
 22: Quantité  (French decimal, e.g. "1,00")
 23: Prix unitaire (French decimal with € sign, e.g. "1 000,00 €")
 24: Montant 2026 (French decimal with € sign)
"""

import csv
import os
import re
from collections import OrderedDict
from datetime import datetime

# =============================================================================
# CONFIGURATION — update these paths before running
# =============================================================================
CSV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Model Import Renewal Charge Map(Sheet1).csv")
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
YEAR = "2026"

# Salesforce constants
OPP_RECORD_TYPE_RENEWAL = "012IV000001jKlBYAU"
CHARGEMAP_RECORD_TYPE_PIXID_FR = "012IV000001yk7WYAQ"
PRICEBOOK_ID = "01sIV000008jTIzYAM"

# Field mappings
ACTIVITY_MAP = {
    "Pixid France": "Pixid FR",
}

PAYMENT_METHOD_MAP = {
    "Transfer": "Transfer",
    "Direct debit": "Direct Debit",
}

PO_REQUIRED_MAP = {
    "True": "true",
    "False": "false",
    "TRUE": "true",
    "FALSE": "false",
}


def parse_date(val):
    """Parse DD/MM/YYYY or YYYY-MM-DD to YYYY-MM-DD."""
    if not val or not val.strip():
        return ""
    val = val.strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(val, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return val


def parse_amount(val):
    """Parse French-formatted monetary value (e.g. '1 000,00 €') to plain float string."""
    if not val or not val.strip():
        return ""
    cleaned = val.strip().replace("€", "").replace(" ", "").replace(",", ".")
    try:
        return str(float(cleaned))
    except ValueError:
        return val.strip()


def safe(val):
    """Return stripped string, empty string for None."""
    if val is None:
        return ""
    return str(val).strip()


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # =========================================================================
    # Read CSV (BOM-safe, semicolon-delimited)
    # =========================================================================
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f, delimiter=";")
        next(reader)  # skip header
        for row in reader:
            if not any(cell.strip() for cell in row):
                continue
            if safe(row[0]):
                rows.append(row)

    print(f"Total data rows: {len(rows)}")

    # =========================================================================
    # Group by Account ID
    # =========================================================================
    accounts = OrderedDict()
    for row in rows:
        account_id = safe(row[0])
        if account_id not in accounts:
            accounts[account_id] = {
                "account_id": account_id,
                "activity": safe(row[8]),
                "offer": safe(row[9]),
                "closing_date": parse_date(safe(row[10])),
                "invoice_sending_method": safe(row[11]),
                "send_invoice_to": safe(row[12]),
                "payment_method": safe(row[13]),
                "billing_instructions": safe(row[15]),
                "billing_conditions": safe(row[16]),
                "po_required": safe(row[17]),
                "po_reference": safe(row[18]),
                "po_request_date": parse_date(safe(row[19])) if len(row) > 19 else "",
                "billing_contact_id": safe(row[20]) if len(row) > 20 else "",
                "cash_collection_id": safe(row[21]) if len(row) > 21 else "",
                "items": [],
            }
        accounts[account_id]["items"].append(row)

    print(f"Unique accounts: {len(accounts)}")

    # =========================================================================
    # 1. Opportunities CSV
    #    Name is a placeholder — import.sh replaces it with the real Account name
    # =========================================================================
    opp_file = os.path.join(OUTPUT_DIR, "opportunities.csv")
    opp_fields = [
        "AccountId",
        "RecordTypeId",
        "Name",
        "StageName",
        "CloseDate",
        "Activity__c",
        "Offer__c",
        "CurrencyIsoCode",
        "ChannelType__c",
        "Pricebook2Id",
    ]
    with open(opp_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=opp_fields)
        writer.writeheader()
        for account_id, acct in accounts.items():
            activity = ACTIVITY_MAP.get(acct["activity"], acct["activity"])
            writer.writerow({
                "AccountId": account_id,
                "RecordTypeId": OPP_RECORD_TYPE_RENEWAL,
                "Name": f"PLACEHOLDER_{account_id} - Pack C&S - {YEAR}",
                "StageName": "Closed - Won",
                "CloseDate": acct["closing_date"] or f"{YEAR}-01-01",
                "Activity__c": activity,
                "Offer__c": acct["offer"],
                "CurrencyIsoCode": "EUR",
                "ChannelType__c": "Direct",
                "Pricebook2Id": PRICEBOOK_ID,
            })
    print(f"Written {len(accounts)} opportunities to {opp_file}")

    # =========================================================================
    # 2. Opportunity Line Items CSV
    #    OpportunityId + PricebookEntryId filled in import.sh
    # =========================================================================
    oli_file = os.path.join(OUTPUT_DIR, "opportunity_line_items.csv")
    oli_fields = [
        "AccountId_ref",   # helper — removed before SF import
        "Product2Id_ref",  # helper — removed before SF import
        "OpportunityId",
        "PricebookEntryId",
        "Quantity",
        "UnitPrice",
        "CurrencyIsoCode",
        "Description",
        "ServiceDate",
    ]
    item_count = 0
    with open(oli_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=oli_fields)
        writer.writeheader()
        for account_id, acct in accounts.items():
            for item_row in acct["items"]:
                quantity = parse_amount(safe(item_row[22])) if len(item_row) > 22 else "1"
                unit_price = parse_amount(safe(item_row[23])) if len(item_row) > 23 else "0"
                writer.writerow({
                    "AccountId_ref": account_id,
                    "Product2Id_ref": safe(item_row[1]),
                    "OpportunityId": "",
                    "PricebookEntryId": "",
                    "Quantity": quantity or "1",
                    "UnitPrice": unit_price or "0",
                    "CurrencyIsoCode": "EUR",
                    "Description": safe(item_row[3]),
                    "ServiceDate": parse_date(safe(item_row[6])),
                })
                item_count += 1
    print(f"Written {item_count} opportunity line items to {oli_file}")

    # =========================================================================
    # 3. Charge Maps CSV
    #    SourceOpportunity__c filled in import.sh
    # =========================================================================
    cm_file = os.path.join(OUTPUT_DIR, "charge_maps.csv")
    cm_fields = [
        "Account__c",
        "RecordTypeId",
        "Type__c",
        "Status__c",
        "CurrencyIsoCode",
        "AutoRenewal__c",
        "Primary__c",
        "BillingConditions__c",
        "InvoiceSendingMethod__c",
        "PaymentMethod__c",
        "SendInvoiceTo__c",
        "BillingInstructions__c",
        "PurchaseOrderRequired__c",
        "PurchaseOrderReference__c",
        "PurchaseOrderRequestDate__c",
        "BillingContact__c",
        "CashCollectionContact__c",
        "SourceOpportunity__c",
    ]
    with open(cm_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=cm_fields)
        writer.writeheader()
        for account_id, acct in accounts.items():
            payment = PAYMENT_METHOD_MAP.get(acct["payment_method"], acct["payment_method"])
            po_req = PO_REQUIRED_MAP.get(acct["po_required"], "false")
            writer.writerow({
                "Account__c": account_id,
                "RecordTypeId": CHARGEMAP_RECORD_TYPE_PIXID_FR,
                "Type__c": "Renewal",
                "Status__c": "Backlog",
                "CurrencyIsoCode": "EUR",
                "AutoRenewal__c": "true",
                "Primary__c": "false",
                "BillingConditions__c": acct["billing_conditions"],
                "InvoiceSendingMethod__c": acct["invoice_sending_method"],
                "PaymentMethod__c": payment,
                "SendInvoiceTo__c": acct["send_invoice_to"],
                "BillingInstructions__c": acct["billing_instructions"],
                "PurchaseOrderRequired__c": po_req,
                "PurchaseOrderReference__c": acct["po_reference"],
                "PurchaseOrderRequestDate__c": acct["po_request_date"],
                "BillingContact__c": acct["billing_contact_id"],
                "CashCollectionContact__c": acct["cash_collection_id"],
                "SourceOpportunity__c": "",
            })
    print(f"Written {len(accounts)} charge maps to {cm_file}")

    # =========================================================================
    # 4. Charge Map Items CSV
    #    ChargeMap__c filled in import.sh
    # =========================================================================
    cmi_file = os.path.join(OUTPUT_DIR, "charge_map_items.csv")
    cmi_fields = [
        "AccountId_ref",  # helper — removed before SF import
        "ChargeMap__c",
        "Product__c",
        "Name",
        "LineDescription__c",
        "BillingSchedule__c",
        "Term__c",
        "Quantity__c",
        "Sales_unit_price__c",
        "Amount__c",
        "Status__c",
        "StartDateRevRec__c",
        "End_date__c",
        "CurrencyIsoCode",
        "PO_Required__c",
        "Activated__c",
    ]
    item_count = 0
    with open(cmi_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=cmi_fields)
        writer.writeheader()
        for account_id, acct in accounts.items():
            for item_row in acct["items"]:
                quantity = parse_amount(safe(item_row[22])) if len(item_row) > 22 else "1"
                unit_price = parse_amount(safe(item_row[23])) if len(item_row) > 23 else "0"
                amount = parse_amount(safe(item_row[24])) if len(item_row) > 24 else "0"
                po_req = PO_REQUIRED_MAP.get(safe(item_row[17]), "false")
                writer.writerow({
                    "AccountId_ref": account_id,
                    "ChargeMap__c": "",
                    "Product__c": safe(item_row[1]),
                    "Name": safe(item_row[2]),
                    "LineDescription__c": safe(item_row[3]),
                    "BillingSchedule__c": safe(item_row[4]),
                    "Term__c": safe(item_row[5]),
                    "Quantity__c": quantity or "1",
                    "Sales_unit_price__c": unit_price or "0",
                    "Amount__c": amount or "0",
                    "Status__c": "Backlog",
                    "StartDateRevRec__c": parse_date(safe(item_row[6])),
                    "End_date__c": parse_date(safe(item_row[7])),
                    "CurrencyIsoCode": "EUR",
                    "PO_Required__c": po_req,
                    "Activated__c": "false",
                })
                item_count += 1
    print(f"Written {item_count} charge map items to {cmi_file}")
    print(f"\nAll files generated in: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
