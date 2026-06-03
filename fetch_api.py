import requests
import pandas as pd
import json

# 1. Fetch API data
url = "https://www.disneyworld.co.uk/finder/api/v1/explorer-service/list-ancestor-entities/wdw/80007798;entityType=destination/2026-08-30/attractions"
response = requests.get(url)

# Check if request was successful
if response.status_code != 200:
    print(f"Error fetching data: {response.status_code}")
    exit()

data = response.json()

# 2. Inspect top-level keys
print("Top-level keys:", list(data.keys()))

# 3. Try to find a list to normalize
# Look for the first key that contains a list
list_key = None
for key, value in data.items():
    if isinstance(value, list):
        list_key = key
        break

if list_key is None:
    print("No list found at top-level. You might need to inspect nested keys manually.")
    exit()

print(f"Flattening data under key: '{list_key}'")

# 4. Normalize JSON into a table
df = pd.json_normalize(data[list_key])

# 5. Save to CSV
df.to_csv("output.csv", index=False)
print("✅ Saved output.csv")
