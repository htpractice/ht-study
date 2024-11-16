import oci
import boto3
import botocore
import argparse

parser = argparse.ArgumentParser(discription="This will get the arguments from command line")
parser.add_argument("-c" , "--count",help="Need the count")
args = parser.parse_args()

aws_config = boto3.Session(profile_name='dev')
oci_config = oci.config.from_file(profile_name = "prod" , region="us-ashbun-1")

def aws_compute():
    #consider that you have all the required nw resources in place like VPC, Subnets and NACL/Security Groups
    
def oci_compute():
    #consider that you have all the required nw resources in place like VCN, Subnets and Security Lists and NSGS

def main():

if __name__ == "__main__":
    main()