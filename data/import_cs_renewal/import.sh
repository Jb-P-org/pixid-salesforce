#!/bin/bash
# =============================================================================
# Import Pack C&S Renewal into Salesforce
#
# Steps:
#   0.  Generate CSVs from source CSV (generate_cs_renewal_import.py)
#   0b. Enrich Opportunity names with real Account names from SF
#   1.  Import Opportunities
#   1b. Query Opportunity IDs → update charge_maps.csv + opportunity_line_items.csv
#   1c. Query PricebookEntry IDs → produce opportunity_line_items_final.csv
#   2.  Import Opportunity Line Items
#   3.  Import Charge Maps
#   3b. Query ChargeMap IDs → produce charge_map_items_final.csv
#   4.  Import Charge Map Items
#
# Prerequisites:
#   - sf CLI authenticated (uses the current default org)
#   - Python 3 (no extra packages needed)
#   - Source CSV path set in generate_cs_renewal_import.py
#
# Usage:
#   cd /Users/clementboschet/Documents/repos/pixid-salesforce
#   bash data/import_cs_renewal/import.sh
# =============================================================================

set -e

ORG_ALIAS=$(sf org display --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['alias'])")
DIR="data/import_cs_renewal"
RUN_DIR="${DIR}/$(date +%Y-%m-%d)"
OPP_RECORD_TYPE_RENEWAL="012IV000001jKlBYAU"
PRICEBOOK_ID="01sIV000008jTIzYAM"

echo "Target org: ${ORG_ALIAS}"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to abort..."
echo ""

# =============================================================================
echo "=========================================="
echo "Step 0: Generate CSVs from source CSV"
echo "=========================================="
python3 "${DIR}/generate_cs_renewal_import.py"

# =============================================================================
echo ""
echo "=========================================="
echo "Step 0b: Validate data"
echo "=========================================="

python3 -c "
import subprocess, json, csv, sys, re
from datetime import datetime

DIR = '${DIR}'
ORG = '${ORG_ALIAS}'
errors = []
warnings = []

def is_sf_id(val):
    return bool(val and re.match(r'^[a-zA-Z0-9]{15,18}$', val.strip()))

def is_date(val):
    try:
        datetime.strptime(val.strip(), '%Y-%m-%d')
        return True
    except:
        return False

def is_positive_number(val):
    try:
        return float(val) > 0
    except:
        return False

def is_nonneg_number(val):
    try:
        return float(val) >= 0
    except:
        return False

# --- Opportunities ---
opp_rows = []
with open(f'{DIR}/opportunities.csv', 'r', encoding='utf-8') as f:
    opp_rows = list(csv.DictReader(f))

for i, r in enumerate(opp_rows, 1):
    if not is_sf_id(r.get('AccountId', '')):
        errors.append(f'Opportunity row {i}: invalid AccountId \"{r.get(\"AccountId\")}\"')
    if not is_date(r.get('CloseDate', '')):
        errors.append(f'Opportunity row {i}: invalid CloseDate \"{r.get(\"CloseDate\")}\"')
    if not r.get('Activity__c', '').strip():
        warnings.append(f'Opportunity row {i}: Activity__c is empty')
    if not r.get('Offer__c', '').strip():
        warnings.append(f'Opportunity row {i}: Offer__c is empty')

# --- Opportunity Line Items ---
oli_rows = []
with open(f'{DIR}/opportunity_line_items.csv', 'r', encoding='utf-8') as f:
    oli_rows = list(csv.DictReader(f))

for i, r in enumerate(oli_rows, 1):
    if not is_sf_id(r.get('Product2Id_ref', '')):
        errors.append(f'OLI row {i}: invalid Product2Id_ref \"{r.get(\"Product2Id_ref\")}\"')
    if not is_positive_number(r.get('Quantity', '')):
        errors.append(f'OLI row {i}: Quantity must be > 0, got \"{r.get(\"Quantity\")}\"')
    if not is_nonneg_number(r.get('UnitPrice', '')):
        errors.append(f'OLI row {i}: UnitPrice must be >= 0, got \"{r.get(\"UnitPrice\")}\"')
    if r.get('ServiceDate') and not is_date(r.get('ServiceDate', '')):
        errors.append(f'OLI row {i}: invalid ServiceDate \"{r.get(\"ServiceDate\")}\"')

# --- Charge Maps ---
cm_rows = []
with open(f'{DIR}/charge_maps.csv', 'r', encoding='utf-8') as f:
    cm_rows = list(csv.DictReader(f))

for i, r in enumerate(cm_rows, 1):
    if not is_sf_id(r.get('Account__c', '')):
        errors.append(f'ChargeMap row {i}: invalid Account__c \"{r.get(\"Account__c\")}\"')
    if not r.get('InvoiceSendingMethod__c', '').strip():
        warnings.append(f'ChargeMap row {i}: InvoiceSendingMethod__c is empty')
    if not r.get('PaymentMethod__c', '').strip():
        warnings.append(f'ChargeMap row {i}: PaymentMethod__c is empty')
    if r.get('PurchaseOrderRequestDate__c') and not is_date(r.get('PurchaseOrderRequestDate__c', '')):
        errors.append(f'ChargeMap row {i}: invalid PurchaseOrderRequestDate__c \"{r.get(\"PurchaseOrderRequestDate__c\")}\"')

# --- Charge Map Items ---
cmi_rows = []
with open(f'{DIR}/charge_map_items.csv', 'r', encoding='utf-8') as f:
    cmi_rows = list(csv.DictReader(f))

for i, r in enumerate(cmi_rows, 1):
    if not r.get('Name', '').strip():
        errors.append(f'ChargeMapItem row {i}: Name is empty')
    if not is_sf_id(r.get('Product__c', '')):
        errors.append(f'ChargeMapItem row {i}: invalid Product__c \"{r.get(\"Product__c\")}\"')
    if not is_positive_number(r.get('Quantity__c', '')):
        errors.append(f'ChargeMapItem row {i}: Quantity__c must be > 0, got \"{r.get(\"Quantity__c\")}\"')
    if not is_nonneg_number(r.get('Sales_unit_price__c', '')):
        errors.append(f'ChargeMapItem row {i}: Sales_unit_price__c must be >= 0, got \"{r.get(\"Sales_unit_price__c\")}\"')
    if r.get('StartDateRevRec__c') and not is_date(r.get('StartDateRevRec__c', '')):
        errors.append(f'ChargeMapItem row {i}: invalid StartDateRevRec__c \"{r.get(\"StartDateRevRec__c\")}\"')
    if r.get('End_date__c') and not is_date(r.get('End_date__c', '')):
        errors.append(f'ChargeMapItem row {i}: invalid End_date__c \"{r.get(\"End_date__c\")}\"')

# --- Verify Account IDs exist in SF ---
account_ids = list(set(r['AccountId'] for r in opp_rows))
ids_str = \"','\".join(account_ids)
result = subprocess.run([
    'sf', 'data', 'query',
    '--query', f\"SELECT Id FROM Account WHERE Id IN ('{ids_str}')\",
    '--target-org', ORG, '--json'
], capture_output=True, text=True)
data = json.loads(result.stdout)
found_ids = {r['Id'] for r in data.get('result', {}).get('records', [])}
for acct_id in account_ids:
    if acct_id not in found_ids:
        errors.append(f'Account {acct_id} not found in Salesforce')

# --- Verify Product2 IDs exist in SF ---
product_ids = list(set(r['Product2Id_ref'] for r in oli_rows if r.get('Product2Id_ref')))
ids_str = \"','\".join(product_ids)
result = subprocess.run([
    'sf', 'data', 'query',
    '--query', f\"SELECT Id FROM Product2 WHERE Id IN ('{ids_str}') AND IsActive = true\",
    '--target-org', ORG, '--json'
], capture_output=True, text=True)
data = json.loads(result.stdout)
found_products = {r['Id'] for r in data.get('result', {}).get('records', [])}
for pid in product_ids:
    if pid not in found_products:
        errors.append(f'Product2 {pid} not found or inactive in Salesforce')

# --- Report ---
print(f'Validated: {len(opp_rows)} Opportunities | {len(oli_rows)} OLIs | {len(cm_rows)} ChargeMaps | {len(cmi_rows)} ChargeMapItems')
for w in warnings:
    print(f'  WARNING: {w}')
for e in errors:
    print(f'  ERROR:   {e}')
if errors:
    print(f'\n{len(errors)} error(s) found — aborting import.')
    sys.exit(1)
print(f'Validation passed ({len(warnings)} warning(s)).')
"

# =============================================================================
echo ""
echo "=========================================="
echo "Step 0a: Enrich Opportunity names with Account names"
echo "=========================================="

python3 -c "
import subprocess, json, csv

rows = []
with open('${DIR}/opportunities.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    rows = list(reader)

account_ids = [r['AccountId'] for r in rows]
ids_str = \"','\".join(account_ids)

result = subprocess.run([
    'sf', 'data', 'query',
    '--query', f\"SELECT Id, Name FROM Account WHERE Id IN ('{ids_str}')\",
    '--target-org', '${ORG_ALIAS}',
    '--json'
], capture_output=True, text=True)

data = json.loads(result.stdout)
records = data.get('result', {}).get('records', [])
name_map = {r['Id']: r['Name'] for r in records}
print(f'Found {len(name_map)} Account names')

for row in rows:
    acct_name = name_map.get(row['AccountId'], row['AccountId'])
    row['Name'] = row['Name'].replace(f'PLACEHOLDER_{row[\"AccountId\"]}', acct_name)

with open('${DIR}/opportunities.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f'Updated {len(rows)} opportunity names')
"

# =============================================================================
echo ""
echo "=========================================="
echo "Step 1: Import Opportunities"
echo "=========================================="
sf data import bulk \
  --sobject Opportunity \
  --file "${DIR}/opportunities.csv" \
  --target-org "$ORG_ALIAS" \
  --line-ending CRLF \
  --wait 10

echo ""
echo "Waiting 3 seconds for records to commit..."
sleep 3

# =============================================================================
echo ""
echo "=========================================="
echo "Step 1b: Resolve Opportunity IDs"
echo "=========================================="

python3 -c "
import subprocess, json, csv

rows_opp = []
with open('${DIR}/opportunities.csv', 'r', encoding='utf-8') as f:
    rows_opp = list(csv.DictReader(f))

account_ids = [r['AccountId'] for r in rows_opp]
ids_str = \"','\".join(account_ids)

result = subprocess.run([
    'sf', 'data', 'query',
    '--query', f\"SELECT Id, AccountId FROM Opportunity WHERE AccountId IN ('{ids_str}') AND RecordTypeId = '${OPP_RECORD_TYPE_RENEWAL}' AND CreatedDate = TODAY\",
    '--target-org', '${ORG_ALIAS}',
    '--json'
], capture_output=True, text=True)

data = json.loads(result.stdout)
records = data.get('result', {}).get('records', [])
opp_map = {r['AccountId']: r['Id'] for r in records}
print(f'Found {len(opp_map)} Opportunity records')

# Update charge_maps.csv
rows = []
with open('${DIR}/charge_maps.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    for row in reader:
        opp_id = opp_map.get(row['Account__c'], '')
        if not opp_id:
            print(f'WARNING: No Opportunity for Account {row[\"Account__c\"]}')
        row['SourceOpportunity__c'] = opp_id
        rows.append(row)

with open('${DIR}/charge_maps.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
print(f'Updated {len(rows)} Charge Map rows with Opportunity IDs')

# Update opportunity_line_items.csv
rows = []
with open('${DIR}/opportunity_line_items.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    for row in reader:
        opp_id = opp_map.get(row['AccountId_ref'], '')
        if not opp_id:
            print(f'WARNING: No Opportunity for Account {row[\"AccountId_ref\"]}')
        row['OpportunityId'] = opp_id
        rows.append(row)

with open('${DIR}/opportunity_line_items.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
print(f'Updated {len(rows)} OLI rows with Opportunity IDs')
"

# =============================================================================
echo ""
echo "=========================================="
echo "Step 1c: Resolve PricebookEntry IDs for OLIs"
echo "=========================================="

python3 -c "
import subprocess, json, csv

rows = []
with open('${DIR}/opportunity_line_items.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    rows = list(reader)

product_ids = list(set(r['Product2Id_ref'] for r in rows if r['Product2Id_ref']))
ids_str = \"','\".join(product_ids)

result = subprocess.run([
    'sf', 'data', 'query',
    '--query', f\"SELECT Id, Product2Id FROM PricebookEntry WHERE Product2Id IN ('{ids_str}') AND Pricebook2Id = '${PRICEBOOK_ID}' AND IsActive = true AND CurrencyIsoCode = 'EUR'\",
    '--target-org', '${ORG_ALIAS}',
    '--json'
], capture_output=True, text=True)

data = json.loads(result.stdout)
records = data.get('result', {}).get('records', [])
pbe_map = {r['Product2Id']: r['Id'] for r in records}
print(f'Found {len(pbe_map)} PricebookEntry records')

for row in rows:
    pbe_id = pbe_map.get(row['Product2Id_ref'], '')
    if not pbe_id:
        print(f'WARNING: No PricebookEntry for Product2 {row[\"Product2Id_ref\"]}')
    row['PricebookEntryId'] = pbe_id

final_fields = [f for f in fieldnames if f not in ('AccountId_ref', 'Product2Id_ref')]
with open('${DIR}/opportunity_line_items_final.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=final_fields, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(rows)
print(f'Written {len(rows)} rows to ${DIR}/opportunity_line_items_final.csv')
"

# =============================================================================
echo ""
echo "=========================================="
echo "Step 2: Import Opportunity Line Items"
echo "=========================================="
sf data import bulk \
  --sobject OpportunityLineItem \
  --file "${DIR}/opportunity_line_items_final.csv" \
  --target-org "$ORG_ALIAS" \
  --line-ending CRLF \
  --wait 10

echo ""
echo "Waiting 3 seconds for records to commit..."
sleep 3

# =============================================================================
echo ""
echo "=========================================="
echo "Step 3: Import Charge Maps"
echo "=========================================="
sf data import bulk \
  --sobject ChargeMap__c \
  --file "${DIR}/charge_maps.csv" \
  --target-org "$ORG_ALIAS" \
  --line-ending CRLF \
  --wait 10

echo ""
echo "Waiting 3 seconds for records to commit..."
sleep 3

# =============================================================================
echo ""
echo "=========================================="
echo "Step 3b: Resolve ChargeMap IDs for items"
echo "=========================================="

python3 -c "
import subprocess, json, csv

result = subprocess.run([
    'sf', 'data', 'query',
    '--query', \"SELECT Id, Account__c FROM ChargeMap__c WHERE Type__c = 'Renewal' AND CreatedDate = TODAY\",
    '--target-org', '${ORG_ALIAS}',
    '--json'
], capture_output=True, text=True)

data = json.loads(result.stdout)
records = data.get('result', {}).get('records', [])
cm_map = {r['Account__c']: r['Id'] for r in records}
print(f'Found {len(cm_map)} ChargeMap records')

rows = []
with open('${DIR}/charge_map_items.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    for row in reader:
        cm_id = cm_map.get(row['AccountId_ref'], '')
        if not cm_id:
            print(f'WARNING: No ChargeMap for Account {row[\"AccountId_ref\"]}')
        row['ChargeMap__c'] = cm_id
        rows.append(row)

final_fields = [f for f in fieldnames if f != 'AccountId_ref']
with open('${DIR}/charge_map_items_final.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=final_fields, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(rows)
print(f'Written {len(rows)} rows to ${DIR}/charge_map_items_final.csv')
"

# =============================================================================
echo ""
echo "=========================================="
echo "Step 4: Import Charge Map Items"
echo "=========================================="
sf data import bulk \
  --sobject ChargeMapItem__c \
  --file "${DIR}/charge_map_items_final.csv" \
  --target-org "$ORG_ALIAS" \
  --line-ending CRLF \
  --wait 10

echo ""
echo "=========================================="
echo "Step 5: Archive import files"
echo "=========================================="
mkdir -p "${RUN_DIR}"
mv "${DIR}/opportunities.csv" \
   "${DIR}/opportunity_line_items.csv" \
   "${DIR}/opportunity_line_items_final.csv" \
   "${DIR}/charge_maps.csv" \
   "${DIR}/charge_map_items.csv" \
   "${DIR}/charge_map_items_final.csv" \
   "${RUN_DIR}/"
echo "Import files archived to ${RUN_DIR}"

echo ""
echo "=========================================="
echo "IMPORT COMPLETE"
echo "=========================================="
