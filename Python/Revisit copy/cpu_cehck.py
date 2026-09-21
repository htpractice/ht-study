#- draft a skeleteon using statements first
#- eg :  Get the threshold from the user compare it with the cpu_percent every second for 5 sec and print status
	
import psutil
	
threshold = (float(input ("Threshold: ")))

for i in range(5):
    if psutil.cpu_percent(interval=1) > threshold:
        print ("Unhealthy")
    else:
        print ("Healthy:",psutil.cpu_percent(interval=1))
    #print (psutil.cpu_percent(interval=1))