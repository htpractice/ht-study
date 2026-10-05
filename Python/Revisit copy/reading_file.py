from pathlib import Path


LEVELS = ("INFO","WARNING","ERROR") # immutable

def read_log_file(path):
    return Path(path).read_text(encoding="utf-8")

def count_log_levels(text):
    counter = {
        "INFO" : 0,
        "WARNING": 0,
        "ERROR":0,
    }
    for line in text.splitlines():
        tokens = line.split() # SPLIT FILE LINES lije "FILENAME" "LOGLEVEL" "ERROR CODE"
        for level in LEVELS:
            if level in tokens:
                counter[level] += 1 #EVerytime a log level is observeed it will be added to dict as count.
    print (counter)

path = ("/Users/thawarh/Documents/Documents_hthaware_mac/Work/ht-study/Python/Revisit/app.log")
text = read_log_file(path)
count_log_levels(text)
