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

def bucket_details():
    bucket_summary = []
    bucket_info = []
    temp_dict = {}
    keys = ["name","region","sizeGB","versioning","createdOn"]
    #print ("Summary for buckets")
    for i in range(len(read_buckets())):
        #print ("================")
        for j in keys:
            summary = f"{j} : " ,read_buckets()[i][j]
            #print (f"{j} : " ,read_buckets()[i][j])
            
            bucket_summary.append(summary)

    for key,value in bucket_summary:
        key = key.strip(" : ")
        temp_dict[key] = value

        if key == "createdOn":
            bucket_info.append(temp_dict)
            temp_dict = {}
    #names = [resource['name'] for resource in bucket_info]
    #print(names) 
    #print (bucket_info)
    return bucket_info

def size_check():
    #bucket_details()
    deletion_queue = []
    cleanup_queue = []
    for details in bucket_details():
        if 100 > details['sizeGB'] >= 80:
            to_clean = details['name'],details['region'],details['sizeGB']
            cleanup_queue.append (to_clean)
            print (("\nName : {0}\nRegion : {1}\nSizeGB : {2}\nCreatedOn : {3}\nRecommendations : Cleanup\n---------".format(details['name'],details['region'],details['sizeGB'],details['createdOn'])))
        else:
            to_del = details['name'],details['region'],details['sizeGB']
            deletion_queue.append = (to_del)
            print (("\nName : {0}\nRegion : {1}\nSizeGB : {2}\nCreatedOn : {3}\nRecommendations : Delete\n---------".format(details['name'],details['region'],details['sizeGB'],details['createdOn'])))
    return

def main():
    print ("bucket summary")
    print ("----------------------------------------------------------")
    for details in bucket_details():
        print ("\nName : {0}, \nRegion : {1}, \nSizeGB : {2}, \nVersioning : {3}\n---------".format(details['name'],details['region'],details['sizeGB'],details['versioning']))

    
    print ("\nClean up Recommended for buckets")
    print ("----------------------------------------------------------")
    size_check()




if __name__ == "__main__":
    main()