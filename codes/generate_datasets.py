import os
import sys

argument = sys.argv
del argument[0]

def isStartWithSelf(x):
    return not x.startswith('generate')

path_dir = './'

folder_list = os.listdir(path_dir)
folder_list = list(filter(isStartWithSelf, folder_list))
# folder_list = folder_list[0:1]

print(folder_list)

TOTAL_COUNTS = 0

for folder in folder_list:
    
    commit_files = os.listdir('/home/pingu/datasets/datasets/' + folder)
    
    for commit_file in commit_files:
        
        entities = commit_file.split("_")
        project_name = entities[0]
        category_name = entities[1]
        print("name: " + project_name)
        print("category: " + category_name)
        commit = open('/home/pingu/datasets/datasets/' + folder + '/' + commit_file)
        contents = commit.readlines()
    
        commit_ids = []
        print(contents)
        print("count: " + str(len(contents)))
        print("********************************************************")
        for content in contents:
            content = content.strip()
            commit_id = content.split(" - ")[0]
            
            commit_ids.append(commit_id)

        dup_commit_ids = []
        for commit_id in commit_ids:
            path_dir = '/home/pingu/datasets/' + project_name + '/' + project_name + '/ecs'
            os.chdir(path_dir)
            # print(path_dir)
            # print('git show ' + commit_id + ' >> ' + commit_id + '_' + category_name + '.ec')
            TOTAL_COUNTS = TOTAL_COUNTS + 1
            if project_name == 'go-ethereum' and commit_id == 'a9b1e7619':
                continue

            if commit_id in dup_commit_ids:
                continue
                
            stream = os.popen('git show ' + commit_id + ' >> ' + commit_id + '_' + category_name + '.ec')
            dup_commit_ids.append(commit_id)
    print("------------------------")

print(TOTAL_COUNTS)