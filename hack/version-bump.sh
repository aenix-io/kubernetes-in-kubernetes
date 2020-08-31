#!/bin/sh
EC=0

version=$(git describe --tags --abbrev=0 | sed -n 's/^v//p')
[ -z "$version" ] && echo "can not determine version from git" && exit 1

echo "bumping version to $version"

f=README.md
sed -i "s/\(kubernetes --version\) [0-9]\+\.[0-9]\+\.[0-9]\+/\1 ${version}/" README.md
git diff --exit-code "$f" && echo "$f not changed" && EC=1

f=deploy/helm/kubernetes/Chart.yaml
sed -i "s/\(^version:\) [0-9]\+\.[0-9]\+\.[0-9]\+/\1 ${version}/" "$f"
git diff --exit-code "$f" && echo "$f not changed" && EC=1

if [ "$EC" != 0 ]; then
  echo
  echo "not all files were changed!"
fi
exit "$EC"
