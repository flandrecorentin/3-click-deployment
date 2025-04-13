import json
import requests
import subprocess
from datetime import datetime

flip_host_script_path = '/3-click-deployment/flip-host.sh'
log_file_path = '/3-click-deployment/logs/cron'
conf_file_path = '/3-click-deployment/config.json'
github_file_path = '/3-click-deployment/.github'
github_api_version = 'v3'
debug = False

def job():
    if debug: print("...Executing cron.py")
    if debug: print_log("-- Start cron", "DEBUG")

    with open(conf_file_path, 'r') as file:
        config_data = json.load(file)

    for config in config_data:
        id = config.get('id')
        github_repository = config.get('github_repository')
        github_owner = config.get('github_owner')
        github_branch = config.get('github_branch')

        if debug:
            print_log("ID: " + id, "DEBUG")
            print_log("ID: " + id, "DEBUG")
            print_log("GitHub Repository: " + github_repository, "DEBUG")
            print_log("GitHub Owner: " + github_owner, "DEBUG")
            print_log("Branch: " + github_branch, "DEBUG")

        new_hash_last_commit = get_new_hash_last_commit(github_owner, github_repository, github_branch)
        old_hash_last_commit = get_field_from_github_file(id)

        if debug: print_log("Hash of new last commit : " + new_hash_last_commit, "DEBUG")
        if debug: print_log("Hash of old last commit : " + old_hash_last_commit, "DEBUG")

        if old_hash_last_commit == "":
            with open(github_file_path, 'a') as file:
                content = "\n"+id+"="+new_hash_last_commit
                file.write(content)
            print_log("Append " + github_file_path + " with " + id + "=" + old_hash_last_commit, "INFO")
        elif new_hash_last_commit != old_hash_last_commit:
            # update hash_last_commit into github file
            with open(github_file_path, 'r') as file:
                file_contents = file.read()
            file_content = file_contents.replace(id+'='+old_hash_last_commit, id+'='+new_hash_last_commit)
            with open(github_file_path, 'w') as file:
                file.write(file_content)
            print_log("Replace " + id + "=" + old_hash_last_commit + " with " + id + "=" + new_hash_last_commit, "INFO")

            # Run flip-host.sh script
            result = subprocess.run(['bash', flip_host_script_path, id], text=True)
        else:
            print_log("Do nothing with " + id + "project", "INFO")
    if debug: print("...Finishing cron.py")
    if debug: print_log("-- End cron", "DEBUG")

def get_new_hash_last_commit(owner, repository, branch):
    url = "https://api.github.com/repos/" + owner + "/" + repository + "/commits/" + branch
    try:
        headers = {
                "Authorization": "token " + get_field_from_github_file("token"),
                "Accept": "application/vnd.github." + github_api_version + ".sha"
            }
        response = requests.get(url, headers=headers)
        # TODO : manage response.status_code
        return response.content.decode('utf-8')
    except Exception as e:
        print_log("Exception getting hash of last commit of the " + repository + " owned by " + owner + " on the branch " + branch, "ERROR")

def get_field_from_github_file(field):
    try:
        with open(github_file_path, 'r') as file:
            for line in file:
                if line.startswith(field+'='):
                    # Extract the field value
                    value = line.split('=')[1].strip()
                    return value
            return ""
    except FileNotFoundError:
        print_log("The file  " + file_path + " does not exist.", "ERROR")
    except Exception as e:
        print_log("Getting  " + field + " value from" + file_path, "ERROR")
    return None

def print_log(s, level = "INFO"):
    now = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    with open(log_file_path, 'a') as file:
        file.write('\n' + '[' + level + '] ' + now + ' : '+ s)

if __name__ == "__main__":
    job()
