set -e
export PATH=/home/user/sdk/flutter/bin:$PATH
cd /home/user/the-wall
shoot() {
  name=$1; shift
  flutter build web --release --no-web-resources-cdn "$@" -o build/m_$name >/dev/null 2>&1
  node tool/still.js /home/user/the-wall/build/m_$name /tmp/claude-0/m/$name.png
}
shoot orbit60   --dart-define=SEED=60   --dart-define=HOUR=13 --dart-define=CAM_YAW=35 --dart-define=CAM_PITCH=24 --dart-define=CAM_DIST=15 --dart-define=CAM_AT=50
shoot year365   --dart-define=SEED=365  --dart-define=HOUR=13 --dart-define=BUDGET=340 --dart-define=CAM_YAW=28 --dart-define=CAM_PITCH=16 --dart-define=CAM_DIST=34 --dart-define=CAM_AT=45
shoot long1100  --dart-define=SEED=1100 --dart-define=HOUR=13 --dart-define=BUDGET=340 --dart-define=CAM_YAW=62 --dart-define=CAM_PITCH=9 --dart-define=CAM_DIST=26 --dart-define=CAM_AT=25
shoot top365    --dart-define=SEED=365  --dart-define=HOUR=13 --dart-define=CAM_YAW=18 --dart-define=CAM_PITCH=78 --dart-define=CAM_DIST=30 --dart-define=CAM_AT=50
shoot decay120  --dart-define=SEED=120  --dart-define=IDLE_DAYS=13 --dart-define=HOUR=13 --dart-define=CAM_YAW=32 --dart-define=CAM_PITCH=18 --dart-define=CAM_DIST=20 --dart-define=CAM_AT=50
shoot dusk365   --dart-define=SEED=365  --dart-define=HOUR=19 --dart-define=CAM_YAW=40 --dart-define=CAM_PITCH=14 --dart-define=CAM_DIST=34 --dart-define=CAM_AT=55
echo done
shoot hero1100  --dart-define=SEED=1100 --dart-define=HOUR=13 --dart-define=BUDGET=340 --dart-define=CAM_YAW=84 --dart-define=CAM_PITCH=7 --dart-define=CAM_DIST=13 --dart-define=CAM_AT=12
shoot far1100   --dart-define=SEED=1100 --dart-define=HOUR=13 --dart-define=BUDGET=340 --dart-define=CAM_YAW=70 --dart-define=CAM_PITCH=11 --dart-define=CAM_DIST=22 --dart-define=CAM_AT=55
