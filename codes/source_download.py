import os
import sys

argument = sys.argv
del argument[0]

def isStartPrefix(x):
    return x.startswith(argument[0])

path_dir = '/home/pingu/datasets/results2'
data_dir = '/home/pingu/datasets'
save_dir = '/home/pingu/datasets/results2/codes'

file_list = os.listdir(path_dir)

file_list = list(filter(isStartPrefix, file_list))

for file in file_list:
    names = file.split("_")
    commit_type = names[len(names)-1]
    project_name = names[3]

    f = open('/home/pingu/datasets/results2/' + file, 'r')
    contents = f.readlines()

    for content in contents:
        content = content.strip()
        if(content.startswith("MARKING_PINGU")):
            os.chdir(path_dir)
            before_commit_id = content.split(' - ')[0]
            commit_msg = content.split(' - ')[1].split(' : ')[1]
            after_commit_id = before_commit_id.split('_')[2]

            os.chdir(data_dir + '/' + argument[0] + '/' + project_name)
            stream = os.popen('git rev-parse ' + after_commit_id)
            output = stream.read()
            final_commit_id = output.strip()
            
            stream = os.popen('git show ' + final_commit_id)
            output = stream.read()
            commit_source_code = output.strip()
            
            file_name = argument[0] + '_' + project_name + '_' + commit_type + '_' + final_commit_id + '.code'

            f = open(save_dir + '/' + file_name, 'w')
            f.write(commit_msg + '\n\n' + commit_source_code)
            f.close()
    
