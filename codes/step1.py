import os
import subprocess
import sys

argument = sys.argv
del argument[0]

path_dir = "/home/pingu/datasets/" + argument[0]
# KEY_WORDS = ["optimize", "cpu", "gpu", "resource", "unuse", "unnecessary", "leak", "waste", "never", 'performance', 'memory', 'mem', 'speed', 'fast', 'slow']
KEY_WORDS = ["performance", "memory", "energy", "leak", "unnecessary", "improve", "expan", "reduce"]
KsEY_WORDS_COUNTS = []

file_list = os.listdir(path_dir)

print(file_list)

TOTAL_COUNTS = 0

for folder in file_list:
    folder_path = path_dir + "/" + folder
    specific_folder_file_list = os.listdir(folder_path)

#    print(specific_folder_file_list)
    os.chdir(folder_path)

    for keyword in KEY_WORDS:
        stream = os.popen('git log --pretty=format:"%h - %an, %ar : %s" | grep "' + keyword + '"')
        output = stream.read()
        f = open('/home/pingu/datasets/results2/' + argument[0] + '_energy_bug_' + keyword, 'w')
        f.write(output)
        f.close()
        print(output)



# result = subprocess.run(["ls", "-l"], stdout=subprocess.PIPE, text=True)
# print(result.stdout)

