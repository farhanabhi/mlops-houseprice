import boto3, joblib, os, tempfile, json, numpy as np

S3_BUCKET = os.environ["MODEL_S3_BUCKET"]
S3_KEY = os.environ.get("MODEL_S3_KEY", "artifacts/model.pkl")

model = None

def load_model():
    global model
    if model is None:
        s3 = boto3.client("s3")
        with tempfile.NamedTemporaryFile(suffix=".pkl") as tmp:
            s3.download_file(S3_BUCKET, S3_KEY, tmp.name)
            model = joblib.load(tmp.name)
    return model

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        features = np.array(body["features"]).reshape(1, -1)
        m = load_model()
        pred = m.predict(features).tolist()
        return {"statusCode": 200, "body": json.dumps({"prediction": pred})}
    except Exception as e:
        return {"statusCode": 400, "body": json.dumps({"error": str(e)})}
