# This bash script generate a list of commits for which there exists no hydra.nix file

git clone https://github.com/hacl-star/hacl-star
git clone https://github.com/fstarlang/karamel
git clone https://github.com/fstarlang/fstar

for repo in */; do
    cd $repo
    for rev in $(git for-each-ref --format='%(objectname:short)' --no-contains=master); do
	git cat-file -e "${rev}:flake.nix" 2>/dev/null ||  echo "$rev"
    done
    cd ..
done | sort -u > blacklist
