set -e
export PATH=/home/user/sdk/flutter/bin:$PATH
cd /home/user/the-wall
shoot() {
  name=$1; shift
  flutter build web --release --no-web-resources-cdn "$@" -o build/c_$name >/dev/null 2>&1 \
    || { echo "BUILD FAILED $name"; return 1; }
  node tool/still.js /home/user/the-wall/build/c_$name /tmp/claude-0/city/$name.png
}
"$@"
