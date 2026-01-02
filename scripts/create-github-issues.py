#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.request


def load_issues(path):
    _, ext = os.path.splitext(path.lower())
    with open(path, "r", encoding="utf-8") as handle:
        content = handle.read()

    if ext in {".yaml", ".yml"}:
        return load_yaml(content, path)
    if ext == ".json":
        return load_json(content, path)

    try:
        return load_json(content, path)
    except ValueError:
        return load_yaml(content, path)


def load_json(content, path):
    try:
        return json.loads(content)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse JSON in {path}: {exc}") from exc


def load_yaml(content, path):
    try:
        import yaml  # type: ignore
    except ImportError as exc:
        raise ValueError(
            "PyYAML is required to parse YAML files. Install with: pip install pyyaml"
        ) from exc
    try:
        return yaml.safe_load(content)
    except yaml.YAMLError as exc:
        raise ValueError(f"Failed to parse YAML in {path}: {exc}") from exc


def normalize_issues(data):
    if not isinstance(data, list):
        raise ValueError("Issues file must be a list of issue objects.")

    normalized = []
    for index, issue in enumerate(data, start=1):
        if not isinstance(issue, dict):
            raise ValueError(f"Issue #{index} is not an object.")

        title = issue.get("title")
        if not title or not isinstance(title, str):
            raise ValueError(f"Issue #{index} is missing a valid title.")

        description = issue.get("description")
        if description is not None and not isinstance(description, str):
            raise ValueError(f"Issue #{index} description must be a string.")

        labels = issue.get("labels")
        if labels is not None:
            if not isinstance(labels, list) or not all(
                isinstance(label, str) for label in labels
            ):
                raise ValueError(f"Issue #{index} labels must be a list of strings.")

        normalized.append(
            {
                "title": title.strip(),
                "body": description.strip() if description else None,
                "labels": labels,
            }
        )

    return normalized


def create_issue(token, repo, issue):
    url = f"https://api.github.com/repos/{repo}/issues"
    payload = {"title": issue["title"]}
    if issue.get("body"):
        payload["body"] = issue["body"]
    if issue.get("labels"):
        payload["labels"] = issue["labels"]

    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "User-Agent": "homelab-issue-script",
        },
    )

    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"GitHub API error {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error: {exc}") from exc


def main():
    parser = argparse.ArgumentParser(
        description="Create GitHub issues from a JSON or YAML file."
    )
    parser.add_argument("--token", required=True, help="GitHub token.")
    parser.add_argument("--file", required=True, help="Path to issues JSON/YAML file.")
    parser.add_argument(
        "--repo",
        required=True,
        help="Target repository in owner/name format (e.g. jgodson/kube-manager).",
    )
    args = parser.parse_args()

    issues = normalize_issues(load_issues(args.file))
    for issue in issues:
        created = create_issue(args.token, args.repo, issue)
        number = created.get("number")
        url = created.get("html_url")
        print(f"Created issue #{number}: {url}")


if __name__ == "__main__":
    main()
