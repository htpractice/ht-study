import json
import os
import sys
import csv


def read_buckets():
    with open ('./buckets.json','r') as file:
        data = json.load(file)
        #print (type(data["buckets"]))
        bucket_list = data["buckets"]
        #print ("Priniting bucket list")
        return bucket_list

def main():
    bucket_summary = []
    bucket_info = []
    temp_dict = {}
    keys = ["name","region","sizeGB","versioning"]
    for i in range(len(read_buckets())):
        #print ("================")
        for j in keys:
            summary = f"{j} : " ,read_buckets()[i][j]
            #print (f"{j} : " ,read_buckets()[i][j])
            bucket_summary.append(summary)

    for key,value in bucket_summary:
        key = key.strip(" : ")
        temp_dict[key] = value

        if key == "versioning":
            bucket_info.append(temp_dict)
            temp_dict = {}
    
    #print (bucket_info)
    names = [resource['name'] for resource in bucket_info]
    print(names)    

    #print (bucket_summary)

if __name__ == "__main__":
    main()