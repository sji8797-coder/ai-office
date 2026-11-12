# 내 메모장 화면 코드 백업

`memo.html`은 claude.ai 아티팩트 '내 메모장'의 화면 코드 백업입니다. 파일 하나에 화면 구조, 모양, 스크립트가 모두 들어 있습니다.

메모 내용과 첨부 파일은 들어 있지 않습니다. 메모는 아티팩트의 저장소(db)에 사용자별로 따로 저장됩니다.

## 게시할 때 필요한 capabilities

| 이름 | 쓰임 | 설정 |
| --- | --- | --- |
| `db` | 메모와 폴더 저장 | 기본값 |
| `user` | 사용자별 저장 위치 구분 | 기본값 |
| `downloads` | 백업 파일, 첨부 파일, 코드 파일 내려받기 | 기본값 |
| `assets` | 파일 첨부와 저장 공간 표시 | 기본값 |
| `sample` | 파일 내용 정리, 작업 기록 정리 | `images: true` |
| `mcp` | 구글 드라이브, 작업 기록 가져오기 | 아래 커넥터와 도구 |

`mcp`에 넣는 커넥터와 도구는 다음과 같습니다.

- Google Drive: `search_files`, `list_recent_files`, `read_file_content`, `download_file_content`, `create_file`, `trash_file`
- Claude Code Remote: `list_sessions`, `list_events`

## 저장 구조

페이지 하나가 문서 하나이고, 폴더 목록은 `_folders` 문서 하나에 모여 있습니다.

`_folders.folders[]`의 각 항목은 `id`, `name`, `order`를 가집니다. `parent`는 선택 필드입니다.

- `parent`: 상위 폴더의 `id`입니다. 없거나 빈 문자열이면 맨 위 폴더입니다.
- 폴더는 세 단계까지 넣을 수 있습니다.
- 상위 폴더가 없어졌거나 서로 물려 있는 폴더는 화면에서 맨 위 폴더로 보입니다.
- 바깥에서 `_folders`를 다시 쓸 때는 기존 항목의 `parent`를 그대로 두어야 합니다. 빼면 그 폴더가 맨 위로 올라갑니다.
