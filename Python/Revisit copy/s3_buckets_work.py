import boto3
import os
import logging
from botocore.exceptions import ClientError

s3 = boto3.resource('s3')

s3_client = boto3.client('s3')

filename = ("/Users/thawarh/Documents/Documents_hthaware_mac/Work/ht-study/Python/Revisit/cheatsheet.txt")
object_name = "cheatsheet.txt"
bucket = "ht-boto3-practice-1-725335002991"

def list_bucket():
    for bucket in s3.buckets.all():
        if "practice" in bucket.name:
            print(bucket.name)


def upload_file(filename,bucket,object_name):
    if object_name is None:
        object_name = os.path.basename(filename)

    try:
        response = s3_client.upload_file(filename,bucket,object_name)
        print ("Object Uploaded")
    except ClientError as e:
        logging.error(e)
        return False
    return True

def main():
    list_bucket()
    #upload_file()

if __name__ == "__main__":
    main()

    
    

