#!/data/data/com.termux/files/usr/bin/sh
SELF=$(realpath "$0")
mkdir -p "$HOME/bahasaku" && cd "$HOME/bahasaku" || exit 1
sed '1,/^__DATA__$/d' "$SELF" | base64 -d | tar xzf -
sh build.sh
exit 0
__DATA__
