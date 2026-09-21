import psutil


#To make it more usable adding it to a function

def get_system_details():
    cpu = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory().percent
    disk = psutil.disk_usage("/").percent

    sys_info = {
        "cpu" : cpu,
        "mem" : mem,
        "disk": disk
    }
    return (sys_info)