from python_graphql_client import GraphqlClient
import json
import os

ghapi = os.environ.get("HBH_SCAN_SECRET")

client = GraphqlClient(endpoint="https://api.github.com/graphql")

def make_query(after_cursor=None):
    return """
{
  repos: search(
    query: "org:useheartbeat fork:false archived:false"
    type: REPOSITORY
    first: 100
    after: AFTER
  ) {
    pageInfo {
      hasNextPage
      endCursor
    }
    repositoryCount
    edges {
      node {
        ... on Repository {
          nameWithOwner
          name
          pushedAt
          sshUrl
        }
      }
    }
  }
}
""".replace(
        "AFTER", '"{}"'.format(after_cursor) if after_cursor else "null"
    )


def fetch_releases(oauth_token):
    repos = []
    releases = []
    repo_names = set()
    has_next_page = True
    after_cursor = None

    while has_next_page:
        data = client.execute(
            query=make_query(after_cursor),
            headers={"Authorization": "Bearer {}".format(oauth_token)},
        )
        for r in data["data"]["repos"]["edges"]:
            repo=r["node"]
            if repo["name"] not in repo_names:
                repos.append(repo)
                repo_names.add(repo["name"])
        has_next_page = data["data"]["repos"]["pageInfo"]["hasNextPage"]
        after_cursor = data["data"]["repos"]["pageInfo"]["endCursor"]
    return repos

# fetch or update all non-archived repos
repos=fetch_releases(ghapi)
os.system("mkdir allcode")
for r in repos:
  if os.path.exists("allcode/"+r["name"]):
    os.system("cd allcode/"+r["name"]+" && git pull")
  else:
    os.system("cd allcode && git clone "+r["sshUrl"])
# run various scans. requires these utilities to be installed
os.system("cd allcode && trivy fs . > ../trivyoutput.txt")
os.system("cd allcode && semgrep scan . > ../sgoutput.txt")
os.system("nmap -sV --script ssh2-enum-algos -Pn -p 22 sftp.prod-useast1.heartbeathealth.com > nmapoutput.txt")