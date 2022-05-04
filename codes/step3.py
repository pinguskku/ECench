import os
import requests
from bs4 import BeautifulSoup

GO_URL = "https://github.com/ethereum/go-ethereum/commit/"
RUST_URL = "https://github.com/openethereum/openethereum/commit/"
ERIGON_URL = "https://github.com/ledgerwatch/erigon/commit/"
NETHERMIND_URL = "https://github.com/NethermindEth/nethermind/commit/"
BESU_URL = "https://github.com/hyperledger/besu/commit/"
COREGETH_URL = "https://github.com/etclabscore/core-geth/commit/"
BOR_URL = "https://github.com/maticnetwork/bor/commit/"

file_list = os.listdir("./results2")
file_path = "/home/pingu/datasets/results2/"

go_count = 0
rust_count = 0
erigon_count = 0
nethermind_count = 0
besu_count = 0
coregeth_count = 0
bor_count = 0

go_commits = []
rust_commits = []
erigon_commits = []
nethermind_commits = []
besu_commits = []
coregeth_commits = []
bor_commits = []

for file in file_list:
    project = file.split("_")[0]
    kind = file.split("_")[3]
    try:
        f = open(file_path + project + "_energy_bug_" + kind, encoding='utf-8')
        contents = f.readlines()
        contents = [v for v in contents if v]
    
        commits = []
    
        for content in contents:
            content = content.strip()
            commit_id = content.split(" - ")[0]
            commits.append(commit_id)

        if project == "go":
            for commit_id in commits:
                response = requests.get(GO_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        go_count = go_count + 1
                        go_commits.append(commit_id)
        elif project == "rust":
            for commit_id in commits:
                response = requests.get(RUST_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        rust_count = rust_count + 1
                        rust_commits.append(commit_id)
            pass
        elif project == "erigon":
            for commit_id in commits:
                response = requests.get(ERIGON_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        erigon_count = erigon_count + 1
                        erigon_commits.append(commit_id)
            pass
        elif project == "nethermind":
            for commit_id in commits:
                response = requests.get(NETHERMIND_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        nethermind_count = nethermind_count + 1
                        nethermind_commits.append(commit_id)
            pass
        elif project == "besu":
            for commit_id in commits:
                response = requests.get(BESU_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        besu_count = besu_count + 1
                        besu_commits.append(commit_id)
            pass
        elif project == "core-geth":
            for commit_id in commits:
                response = requests.get(COREGETH_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        coregeth_count = coregeth_count + 1
                        coregeth_commits.append(commit_id)
            pass
        elif project == "bor":
            for commit_id in commits:
                response = requests.get(BOR_URL + commit_id)
                if response.status_code == 200:
                    html = response.text
                    soup = BeautifulSoup(html, 'html.parser')
                    title = soup.select_one(".commit-title.markdown-title")
                    pull_tag = title.select_one('a')
                    
                    if pull_tag == None:
                        print("no")
                    else:
                        bor_count = bor_count + 1
                        bor_commits.append(commit_id)
            pass
    except:
        continue


print("go-ethereum: ", go_count)
print("openethereum: ", rust_count)
print("erigon: ", erigon_count)
print("nethermind: ", nethermind_count)
print("besu: ", besu_count)
print("core-geth: ", coregeth_count)
print("bor: ", bor_count)
