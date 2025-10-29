from sklearn.datasets import fetch_california_housing
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import joblib, json, os

os.makedirs("artifacts", exist_ok=True)

# Load data
data = fetch_california_housing()
X_train, X_test, y_train, y_test = train_test_split(
    data.data, data.target, test_size=0.2, random_state=42
)

# Train model
model = RandomForestRegressor(n_estimators=50, random_state=42)
model.fit(X_train, y_train)

# Save model
joblib.dump(model, "artifacts/model.pkl")

# Save accuracy
score = model.score(X_test, y_test)
with open("artifacts/metrics.json", "w") as f:
    json.dump({"r2_score": score}, f)

print("✅ Model trained and saved to artifacts/model.pkl")
