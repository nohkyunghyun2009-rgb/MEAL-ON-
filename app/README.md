# MEAL:ON 앱 (Flutter) — 여기서 고치면 QR 앱이 바뀌어요

이 폴더가 **앱의 진짜 소스**예요. 여기서 코드를 고치고 GitHub에 올리면(push)
GitHub Actions가 자동으로 빌드해서 아래 주소에 올려줘요. QR 코드는 이 주소를 가리켜요.

- 앱 주소: https://nohkyunghyun2009-rgb.github.io/MEAL-ON-/app/
- QR 코드: `docs/app-qr.png` (소개 사이트 맨 아래에도 있어요)
- 배포 상태: GitHub 저장소 → Actions 탭 (push 후 3~5분)

## 처음 한 번: 내 컴퓨터에 받기
```bash
cd ~/Desktop
git clone -b claude/great-archimedes-ll4n7g https://github.com/nohkyunghyun2009-rgb/MEAL-ON-.git
cd MEAL-ON-/app
cp lib/config/app_keys.example.dart lib/config/app_keys.dart   # 그리고 이 파일에 내 키를 적어요 (GitHub엔 안 올라가요)
flutter pub get
flutter run -d web-server --web-port 8081
```
VS Code에서는 `MEAL-ON-/app` 폴더를 여세요.

## 고친 걸 QR 앱에 반영하기
1. VS Code 왼쪽 "Source Control"(가지 모양 아이콘) 클릭
2. 위 칸에 뭘 고쳤는지 한 줄 적기 (예: "홈 색 바꿈") → **Commit**
3. **Sync Changes** (또는 Push) → 처음이면 GitHub 로그인 창이 떠요
4. 3~5분 뒤 QR을 다시 찍으면 바뀐 앱이 떠요 (폰에서 새로고침 한 번)

터미널로 하려면:
```bash
git add -A && git commit -m "뭘 고쳤는지" && git push
```

## 열쇠(API 키)는 GitHub Secrets에
배포 서버는 내 컴퓨터의 `app_keys.dart`를 모르니까, 저장소 **Settings → Secrets and variables → Actions → New repository secret** 에 넣어요.
| 이름 | 값 |
|---|---|
| `GEMINI_API_KEY` | 제미나이 키 (AQ. 또는 AIza 로 시작) |
| `KAKAO_REST_API_KEY` | 카카오 REST API 키 |
| `KAKAO_JS_KEY` | 카카오 JavaScript 키 |
| `CLAUDE_API_KEY` | (선택) Claude 키 |

넣은 뒤 Actions 탭에서 "Run workflow"를 한 번 눌러주면 바로 반영돼요.
⚠️ 웹앱에 들어간 키는 주소를 아는 사람이 볼 수 있어요. 카카오 개발자 사이트 → 플랫폼 → Web 에
`https://nohkyunghyun2009-rgb.github.io` 를 등록하고, 키는 발표용 임시 키로 쓰다가 끝나면 새로 발급받는 걸 권해요.

## 폴더
- `lib/` 앱 코드 (services/local_coach.dart 추천 엔진, state/app_state.dart AI 프롬프트, screens/ 화면)
- `test/` 테스트 (`flutter test`)
- `web/` 웹 설정, `assets/characters/` 밀온이 그림
