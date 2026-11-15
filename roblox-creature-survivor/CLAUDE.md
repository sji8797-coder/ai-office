# roblox-creature-survivor

로블록스 3D 크리처 서바이버(뱀서라이크) MVP. Rojo 프로젝트이며 VS Code 에서 이 폴더를 열어 작업한다.

## 작업 흐름

1. 이 폴더를 VS Code 로 열면 `Rojo: serve` 태스크가 자동으로 실행된다.
   Roblox Studio 에서 Rojo 플러그인의 Connect 를 눌러 두면, 저장한 파일이 Studio 에 바로 반영된다.
2. 코드를 고친 뒤에는 VS Code 의 문제(Problems) 목록에서 Luau LSP 진단을 확인하고,
   새로 생긴 타입 오류와 경고를 모두 없앤다.
3. 동작 확인은 Studio 에서 플레이해서 한다.
   - Roblox Studio MCP 도구가 연결되어 있으면: 플레이를 시작하고, 콘솔 출력을 읽어 오류가 없는지 확인한 뒤 멈춘다.
   - 연결되어 있지 않으면: 사용자에게 Studio 에서 플레이(F5)해 달라고 하고, 출력 창의 오류를 받아서 고친다.
4. 확인하지 못한 것을 확인했다고 말하지 않는다. Studio 에서 돌려 보지 못했으면 그렇게 적는다.

`Rojo: serve` 가 떠 있지 않으면 터미널에서 `rojo serve default.project.json` 을 실행한다.
`rojo` 명령이 없으면 사용자에게 `rokit install` 을 실행해 달라고 한다.

## 디렉토리 구조

| 경로 | Studio 위치 | 종류 |
|---|---|---|
| `src/client/*.client.luau` | `StarterPlayer.StarterPlayerScripts` | LocalScript |
| `src/server/*.server.luau` | `ServerScriptService` | Script |
| `src/server/*.luau` | `ServerScriptService` | ModuleScript |

매핑을 바꾸면 `default.project.json` 도 함께 고친다.

## 코딩 규칙

- 모든 파일 첫 줄에 `--!strict` 를 쓰고 타입을 명시한다.
- 생략이나 `TODO` 없이 그대로 동작하는 코드를 쓴다.
- 대량으로 생기는 오브젝트(몬스터, 투사체, 구슬)는 `Anchored = true`, `CanCollide = false` 로 두고
  물리나 `Touched` 대신 거리 계산(Magnitude)으로 판정한다.
- 매 프레임 도는 루프 안에서는 인스턴스 프로퍼티를 반복해서 읽지 말고 값을 캐시한다.

## 현재 있는 시스템

- `src/client/CameraController.client.luau`: 쿼터뷰 고정 카메라 (Scriptable, 오프셋 Y+25 / Z+20).
- `src/server/ExperienceSystem.server.luau`: 경험치 구슬 드롭과 자석 흡수.
  `ServerStorage` 의 `DropGem` BindableEvent 로 `Fire(position, xpValue?, ignoreInstance?)` 를 받고,
  획득한 경험치는 `Player` 의 `XP` Attribute 에 쌓는다.
- 몬스터 추적 AI 와 투사체 자동 공격 스크립트는 아직 이 저장소에 없다.
  사용자가 가진 파일을 `src/server` 에 넣은 뒤, 몬스터가 죽는 곳에서 `DropGem` 을 호출하도록 연결해야 한다.
