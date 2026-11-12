---
name: memo-log
description: 이번 세션에서 한 작업을 사용자의 '내 메모장' 아티팩트의 '작업 기록' 폴더에 새 페이지로 정리해 남긴다. 작업을 마쳤을 때, 또는 사용자가 /memo-log, "메모장에 정리해줘", "작업 기록 남겨줘"라고 할 때 쓴다.
---

# 메모장에 작업 기록 남기기

이번 세션에서 한 일을 '내 메모장' 아티팩트에 페이지 하나로 남긴다. 메모장은 페이지를
아티팩트 데이터베이스에 문서로 저장하므로, 페이지 코드를 다시 게시하지 않고 문서만 쓴다.

## 순서

1. **메모장 찾기.** `Artifact` 도구의 `action: "list"`로 제목이 `내 메모장`인 내 아티팩트의 URL을 찾는다.
   없으면 아무것도 쓰지 않고 사용자에게 알린다. URL을 저장소 파일에 적지 않는다.
2. **폴더 확인.** `ArtifactData`(목록에 없으면 ToolSearch의 `select:ArtifactData`로 불러온다)로
   collection `data/users/me`의 문서 `_folders`를 `get` 한다.
   `folders` 배열에 `id`가 `work-log`인 항목이 없을 때만
   `{"id":"work-log","name":"작업 기록","order":<가장 큰 order + 1>}`을 추가하고,
   `updated`를 지금 시각(밀리초)으로 바꿔, 읽은 `version`을 `if_version`으로 넣어 `set` 한다.
   다른 폴더 항목은 그대로 둔다.
3. **페이지 쓰기.** 문서 id는 `log-<YYYYMMDD>-<영문 소문자·숫자 6자>`로 정한다(날짜는 한국 시간).
   이 세션에서 이미 쓴 페이지가 있으면 새로 만들지 말고 그 문서를 `get` 한 뒤
   `version`을 `if_version`으로 넣어 덮어쓴다.
4. **확인.** 쓴 문서를 한 번 `get` 해서 들어갔는지 확인하고, 사용자에게 페이지 제목을 한 줄로 알린다.

## 문서 형식

```json
{
  "title": "2026. 11. 13. 로그인 화면 오류 수정",
  "order": 1794498900,
  "updated": 1794498900000,
  "pinned": false,
  "trashed": 0,
  "folder": "work-log",
  "blocks": [
    {"id": "wl000001", "type": "callout", "html": "ai-office 저장소 · claude/fix-login 브랜치", "checked": false},
    {"id": "wl000002", "type": "h3", "html": "요청한 것", "checked": false},
    {"id": "wl000003", "type": "bullet", "html": "로그인 버튼을 눌러도 반응이 없는 문제 고치기", "checked": false},
    {"id": "wl000004", "type": "h3", "html": "한 일", "checked": false},
    {"id": "wl000005", "type": "bullet", "html": "<b>index.html</b>: 버튼 이벤트 연결 수정", "checked": false},
    {"id": "wl000006", "type": "h3", "html": "결과와 확인한 것", "checked": false},
    {"id": "wl000007", "type": "bullet", "html": "브라우저에서 로그인 흐름을 한 번 돌려 확인함", "checked": false},
    {"id": "wl000008", "type": "h3", "html": "남은 일", "checked": false},
    {"id": "wl000009", "type": "todo", "html": "휴대폰 화면에서 다시 확인", "checked": false},
    {"id": "wl000010", "type": "text", "html": "", "checked": false}
  ]
}
```

- `title`: `YYYY. M. D. <작업을 한 줄로>`.
- `order`: 지금 시각(초). `updated`: 지금 시각(밀리초). 둘 다 숫자.
- `blocks[].id`: 문서 안에서 겹치지 않는 영문 소문자·숫자 8자 이상.
- `blocks[].type`: `callout`, `h2`, `h3`, `text`, `bullet`, `number`, `todo`, `quote`, `code`, `divider` 중 하나.
- `blocks[].html`: 글자만 넣는다. `&`, `<`, `>`는 `&amp;`, `&lt;`, `&gt;`로 바꾼다.
  쓸 수 있는 태그는 `<b>`, `<i>`, 그리고 `https://` 주소로 가는 `<a href="...">`뿐이다.
- 마지막 블록은 빈 `text` 블록으로 둔다.

## 내용 규칙

- 요청한 것, 한 일(바뀐 파일과 이유), 결과와 확인한 것, 남은 일을 적는다. 해당 없는 항목은 뺀다.
- 실제로 한 일만 적는다. 확인하지 않은 것을 확인했다고 쓰지 않는다. 실패하거나 건너뛴 것은 그대로 적는다.
- 브랜치 이름, 커밋, PR 링크가 있으면 적는다.
- 비밀번호, 토큰, API 키, 개인 연락처는 적지 않는다.
- 한 블록에는 한두 문장만 쓴다. 긴 코드나 로그는 옮기지 않는다.

## 하지 않는 것

- `_folders`와 이번에 쓰는 `log-...` 문서 말고는 어떤 문서도 고치거나 지우지 않는다.
- 메모장 페이지(HTML)를 다시 게시하지 않는다.
- 메모장 URL이나 사용자 id를 저장소 파일, 커밋 메시지, PR에 적지 않는다.
