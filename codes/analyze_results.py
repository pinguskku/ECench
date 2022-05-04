import os
import sys

argument = sys.argv
del argument[0]

path_dir = './results2'

file_list = os.listdir(path_dir)

TOTAL_COUNTS = 0

ALL_TYPES = []

TYPE_COUNTS = {}
TEMP_COUNTS = 0

for file in file_list:
    TEMP_COUNTS = 0
    if not file.startswith(argument[0]):
        continue
    names = file.split("_")
    commit_type = names[len(names)-1]
    
    f = open(path_dir + '/' + file, 'r')
    contents = f.readlines()
    
    for content in contents:
        if(content.strip().startswith("MARKING_PINGU")):
            TOTAL_COUNTS = TOTAL_COUNTS + 1
            TEMP_COUNTS = TEMP_COUNTS + 1

    try:
        TYPE_COUNTS[commit_type] = TYPE_COUNTS[commit_type] + TEMP_COUNTS
    except:
        TYPE_COUNTS[commit_type] = TEMP_COUNTS

print(TYPE_COUNTS)

print(TOTAL_COUNTS)
