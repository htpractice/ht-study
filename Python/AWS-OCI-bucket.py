import boto3
import botocore
import oci
import argparser

parser = argparser.ArgumentParser(description='Cretae two types of cloud buckets AWS and OCI')
parser.add_argument('-b','--bucket_type', help="AWS bucket or OCI bucket")
args = parser.parse_args()

session = boto3.Session(profile_name='my-sso-profile')

def create_s3_bucket(bucket_name, region="us-east-1"):
    s3_client = boto3.client('s3', region_name=region)
    try:
        s3_client.create_bucket(Bucket=bucket_name,CreateBucketConfiguration={'LocationConstraint': region})
        print (f'Bucket "{ bucket_name }" created')
    except botocore.execptions.ClientError as e:
        if e.reponse['Error']['Code'] == 'Bucket AlreadyOwnedByYou':
            print(f'Bucket "{bucket_name}"already exists')
        else:
            print(f'error creating bucket: {e}')

oci_config = oci.config.from_file(profile_name = "prod" , region="us-ashbun-1")

def create_oci_bucket(bucket_name, region="us-ashburn-1"):
    object_storage_client = oci.object_storage.ObjectStorageClient(oci_config)
    namespace = oci.object_storage.ObjectStorageClient(oci_config).get_namespace().data

    try:
        object_storage_client.crete_bucket(
            namespace,
            oci.object_storage.models.CreateBucketDetails(
                name=bucket_name,
                compartment_id="ocid1.test.oc1..<unique_ID>EXAMPLE-compartmentId-Value",
                storage_tier='Standard',
                region_name=region
            )
        )
    except oci.exceptions.ServiceError as e:
        if e.status == 400:
            print (f'bucket created')
        else:
            print (f'Error { e }')
def main():
    if args.b == "AWS":
        create_s3_bucket('test-bucket')
    if args.b == "OCI":
        create_oci_bucket('test-bucket')
    else:
        print (f'No args provided skipping creation')


if __name__ == "__main__":
    main()






    