import os

file_list = os.listdir("./results2")

KEY_WORDS = ["performance", "memory", "energy", "leak", "unnecessary", "improve", "expan", "reduce"]
PROJECTS = ["besu", "bor", "core-geth", "erigon", "go", "nethermind", "rust"]

BESU_RESULTS = []
BOR_RESULTS = []
COREGETH_RESULTS = []
ERIGON_RESULTS = []
GO_RESULTS = []
NETHERMIND_RESULTS = []
RUST_RESULTS = []

for file in file_list:
    project = file.split("_")[0]
    kind = file.split("_")[3]

    file_name = project + "_energy_bug_" + kind
    
    content = open("/home/pingu/datasets/results2/" + file_name)
    content = content.readlines()
    content = [v for v in content if v]
    
    if project == "besu":
        BESU_RESULTS.append(kind + "_" + str(len(content)))
    elif project == "bor":
        BOR_RESULTS.append(kind +  "_" + str(len(content)))
    elif project == "core-geth":
        COREGETH_RESULTS.append(kind + "_" + str(len(content)))
    elif project == "erigon":
        ERIGON_RESULTS.append(kind + "_" + str(len(content)))
    elif project == "go":
        GO_RESULTS.append(kind + "_" + str(len(content)))
    elif project == "nethermind":
        NETHERMIND_RESULTS.append(kind + "_" + str(len(content)))
    elif project == "rust":
        RUST_RESULTS.append(kind + "_" + str(len(content)))

print("besu", BESU_RESULTS)
print("bor", BOR_RESULTS)
print("core-geth", COREGETH_RESULTS)
print("erigon", ERIGON_RESULTS)
print("go", GO_RESULTS)
print("nethermind", NETHERMIND_RESULTS)
print("rust", RUST_RESULTS)


