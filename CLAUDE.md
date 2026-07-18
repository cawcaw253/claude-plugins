# CLAUDE.md

cawcaw253의 Claude Code 플러그인 마켓플레이스 repo. 구조와 사용법은 `README.md` 참고.

## 커밋 규칙 (필수)

이 repo에서 `git commit` 을 수행할 때는 **항상** 아래 규칙을 지킨다.
직접 커밋하든 `/commit` 커맨드를 쓰든 동일하게 적용된다.

1. **Conventional Commits 형식을 반드시 지킨다.**
   - `<type>(<optional scope>): <description>` 형식.
   - `type` 은 `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` 중 하나.
   - `description` 은 소문자 명령형 현재시제, 끝에 마침표 없음.
   - 파괴적 변경은 `type!:` 또는 footer `BREAKING CHANGE:`.

2. **co-authored-by 등 트레일러/서명을 반드시 제거한다.**
   - `Co-Authored-By:` / `Co-authored-by:` 를 커밋 메시지에 넣지 않는다.
   - `Generated with ...`, `🤖 ...` 등 도구 서명/자동 생성 문구도 넣지 않는다.
   - 이 규칙은 전역 설정의 co-authored-by 요구사항보다 **우선한다**.

3. 커밋 전 절차와 검증은 `/commit` 커맨드(`.claude/commands/commit.md`)를 따른다.
   커밋 요청 시 `/commit` 커맨드를 사용하는 것을 기본으로 한다.

4. 커밋 후 `git log -1 --format='%B'` 로 형식과 트레일러 부재를 확인하고,
   위반 시 `git commit --amend` 로 즉시 수정한다.
