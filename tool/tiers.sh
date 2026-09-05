set -e
export PATH=/home/user/sdk/flutter/bin:$PATH
cd /home/user/the-wall
shoot() {
  name=$1; shift
  flutter build web --release --no-web-resources-cdn "$@" -o build/t_$name >/dev/null 2>&1
  node tool/still.js /home/user/the-wall/build/t_$name /tmp/claude-0/t/$name.png
}
"$@"
