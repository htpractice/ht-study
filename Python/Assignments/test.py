import requests
import os


URL = "https://api.github.com/repos/kubernetes/kubernetes/pulls"

def get_user_pull_requests(user_no):
    try:
        response = requests.get(URL)
    except requests.status_codes == "404":
        print ("Not Found")
        return
    print (response.json()[user_no]["user"]["login"])

def main ():
    user = int(input ("Provide user number:\n"))
    get_user_pull_requests(user)


if __name__ == "__main__":
    main()