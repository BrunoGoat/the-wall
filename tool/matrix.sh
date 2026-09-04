set -e
export PATH=/home/user/sdk/flutter/bin:$PATH
cd /home/user/the-wall
shoot() {
  name=$1; shift
  flutter build web --release --no-web-resources-cdn "$@" -o build/m_$name >/dev/null 2>&1
  node tool/still.js /home/user/the-wall/build/m_$name /tmp/claude-0/m/$name.png
}
C="--dart-define=SEED=365 --dart-define=BUDGET=320 --dart-define=CAM_YAW=48 --dart-define=CAM_PITCH=7 --dart-define=CAM_DIST=26 --dart-define=CAM_AT=45"
shoot h06 $C --dart-define=HOUR=6
shoot h09 $C --dart-define=HOUR=9
shoot h13 $C --dart-define=HOUR=13
shoot h18 $C --dart-define=HOUR=18
shoot h20 $C --dart-define=HOUR=20
shoot h23 $C --dart-define=HOUR=23
shoot back --dart-define=SEED=120 --dart-define=HOUR=11 --dart-define=BUDGET=340 --dart-define=CAM_YAW=205 --dart-define=CAM_PITCH=26 --dart-define=CAM_DIST=12 --dart-define=CAM_AT=40
echo done
