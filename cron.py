# crontab -e
# * * * * * command_to_execute
# * * * * * /home/user/scripts/run_every_second.sh
# 0 2 * * * python3 cron-portfolio.py >> /3-click-deployment/logs/portfolio.3-click-deployment.log 2>&1
import json
import requests
import subprocess

flip_host_script_path = '/3-click-deployment/flip-host.sh'
github_file_path = '/3-click-deployment/.github'
github_api_version = 'v3'

def job():
    print("------------------\n[INFO] start cron")

    with open('config.json', 'r') as file:
        config_data = json.load(file)

    for config in config_data:
        id = config.get('id')
        github_repository = config.get('github_repository')
        github_owner = config.get('github_owner')
        github_branch = config.get('github_branch')

        print(f"ID: {id}")
        print(f"GitHub Repository: {github_repository}")
        print(f"GitHub Owner: {github_owner}")
        print(f"Branch: {github_branch}")
        print("-" * 40)

        new_hash_last_commit = get_new_hash_last_commit(github_owner, github_repository, github_branch)
        print(f"[INFO] Hash of new last commit : {new_hash_last_commit}")

        old_hash_last_commit = get_field_from_github_file(id)
        print(f"[INFO] Hash of old last commit : {old_hash_last_commit}")

        if old_hash_last_commit == "":
            with open(github_file_path, 'a') as file:
                content = "\n"+id+"="+new_hash_last_commit
                file.write(content)
            print(f"[INFO] Append {github_file_path} with {id}={old_hash_last_commit}")
        elif new_hash_last_commit != old_hash_last_commit:
            # update hash_last_commit into github file
            with open(github_file_path, 'r') as file:
                file_contents = file.read()
            file_content = file_contents.replace(id+'='+old_hash_last_commit, id+'='+new_hash_last_commit)
            with open(github_file_path, 'w') as file:
                file.write(file_content)
            print(f"[INFO] Replace {id}={old_hash_last_commit} with {id}={new_hash_last_commit}")

            # Run flip-host.sh script
            # result = subprocess.run(['bash', flip_host_script_path, id], capture_output=True, text=True)
            result = subprocess.run(['bash', flip_host_script_path, id], text=True)
            # do I need to print result ?
        else:
            print(f"[INFO] Do nothing with {id} project")
    print("[INFO] end cron\n---------------------------\n")

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
        print(f"[ERROR] Exception getting hash of last commit of the {repository} owned by {owner} on the branch {branch}")

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
        print(f"[ERROR]: The file {file_path} does not exist.")
    except Exception as e:
        print(f"[ERROR] getting {field} value from {file_path}")
    return None

if __name__ == "__main__":
    job()
