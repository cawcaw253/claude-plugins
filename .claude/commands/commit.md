---
description: 이 repo의 커밋 규칙(Conventional Commits, co-authored-by 제거)에 맞춰 git 커밋을 수행한다
---

# /commit — 규칙 준수 커밋

이 repo의 **커밋 규칙**을 강제하며 커밋한다. 아래 절차를 정확히 따른다.

## 1. 변경 사항 확인

먼저 현재 상태를 병렬로 확인한다.

- `git status`
- `git diff`(staged + unstaged) — 이미 스테이징된 변경도 `git diff --staged`로 확인
- `git log --oneline -10` — 이 repo의 메시지 스타일 참고

스테이징된 파일이 없으면, 관련 변경 파일을 의도에 맞게 `git add` 한다.
관련 없는 변경을 한 커밋에 섞지 않는다.

## 2. 커밋 메시지 작성 규칙 (필수)

### Conventional Commits 형식

```
<type>(<optional scope>): <description>

[optional body]

[optional footer]
```

- **type** 은 다음 중 하나만 사용한다:
  `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **description** 은 소문자로 시작하는 명령형 현재시제, 끝에 마침표를 찍지 않는다.
- 파괴적 변경은 `type!:` 또는 footer에 `BREAKING CHANGE:` 를 사용한다.
- 제목(첫 줄)은 72자 이내를 권장한다.
- 본문/제목은 이 repo의 주 언어(한국어) 스타일에 맞춘다.

**올바른 예시**

```
feat(commit): add conventional commit command
fix(hooks): correct matcher regex for edit tool
docs: update README installation steps
```

### co-authored-by 등 트레일러 제거 (필수)

커밋 메시지에 다음을 **절대 포함하지 않는다**:

- `Co-Authored-By:` / `Co-authored-by:` 등 모든 co-author 트레일러
- `Generated with ...`, `🤖 ...` 등 도구 서명/자동 생성 문구

> 이 규칙은 이 repo의 기본값이며, 전역 설정의 co-authored-by 트레일러 요구사항보다 **우선한다**.

## 3. 커밋 실행

`-m` 플래그를 사용해 위 규칙에 맞는 메시지로 커밋한다.
HEREDOC을 쓰는 경우에도 co-author/서명 트레일러를 넣지 않는다.

```bash
git commit -m "<type>(<scope>): <description>"
```

## 4. 검증

커밋 후 `git log -1 --format='%B'` 로 실제 메시지를 확인해
- Conventional Commits 형식을 지켰는지
- co-authored-by / 도구 서명이 없는지

를 점검한다. 위반이 발견되면 `git commit --amend` 로 즉시 수정한다.

요청하지 않은 이상 `git push` 는 하지 않는다.
