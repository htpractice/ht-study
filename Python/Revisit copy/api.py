from fastapi import FastAPI #F and A is capital as its a class -> which has all the object -> has all the functions we need.
from sys_info import get_system_details
import boto3
#from s3_buckets_work import list_bucket
s3 = boto3.resource('s3')
s3_client = boto3.client('s3')
app = FastAPI(title="Revising Python")

@app.get("/hello")
def hello():
    return {"message" : "Keep you basics strong"}

@app.get("/metrics")
def system_metrics():
    return(get_system_details())

@app.get("/aws/s3")
def get_buckets():
    buckets = []
    for bucket in s3.buckets.all():
        if "practice" in bucket.name:
            buckets.append(bucket.name)
    return buckets

