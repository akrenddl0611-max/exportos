#!/bin/bash
# OECD 국가등급 수동 갱신 스크립트 (로컬 실행용)
# 사유: data.go.kr가 GitHub Actions(해외 IP) 접근을 차단하여 CI 자동화 불가 — 월간 점검 이슈에서 이 스크립트 실행을 안내
# 사용: bash scripts/refresh_oecd.sh && git add data/ && git commit -m "data: OECD 등급 갱신 $(date +%F)" && git push
set -e
cd "$(dirname "$0")/.."
JSON=$(curl -sL -A "Mozilla/5.0" "https://www.data.go.kr/tcs/dss/selectFileDataDownload.do?publicDataPk=3078608&publicDataDetailPk=uddi:d0a38f3b-fd67-4807-a45a-9cea84dad0e2")
ATCH=$(echo "$JSON" | python3 -c "import json,sys;print(json.load(sys.stdin).get('atchFileId',''))")
FNAME=$(echo "$JSON" | python3 -c "import json,sys;print(json.load(sys.stdin).get('fileDataRegistVO',{}).get('orginlFileNm',''))")
[ -z "$ATCH" ] && { echo "atchFileId 확인 실패 — 중단(부분 저장 없음)"; exit 1; }
curl -sL -A "Mozilla/5.0" "https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=${ATCH}&fileDetailSn=1" -o /tmp/oecd_raw.csv
iconv -f cp949 -t utf-8 /tmp/oecd_raw.csv > /tmp/oecd_new.csv 2>/dev/null || cp /tmp/oecd_raw.csv /tmp/oecd_new.csv
HEAD=$(head -1 /tmp/oecd_new.csv); ROWS=$(wc -l < /tmp/oecd_new.csv)
case "$HEAD" in *국가명*) : ;; *) echo "필수 컬럼(국가명) 불일치 — 저장하지 않음"; exit 1;; esac
[ "$ROWS" -lt 150 ] && { echo "행 수 부족($ROWS) — 저장하지 않음"; exit 1; }
V=$(echo "$FNAME" | grep -oE '[0-9]{6}' | tail -1)
if [ -n "$V" ]; then DV="20${V:0:2}-${V:2:2}-${V:4:2}"; else DV=$(date +%F); fi
cp /tmp/oecd_new.csv data/oecd_country_grade.csv
printf '{"dataVersion":"%s","fetchedAt":"%s","source":"data.go.kr 3078608 (K-SURE OECD 국가등급) — scripts/refresh_oecd.sh 수동 실행"}\n' "$DV" "$(date -u +%FT%TZ)" > data/oecd_meta.json
echo "갱신 완료: 기준일 $DV, ${ROWS}행 — git add data/ 후 커밋·푸시하세요"
