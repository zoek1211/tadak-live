/**
 * 상단 오른쪽 버튼(로그인·회원가입). 앱에는 자체 로그인·가입 화면이 없고(의도 문서), 웹 화면(/login, /signup)을 앱 안 창으로 연다.
 * 앱의 웹 창들은 로그인 상태(쿠키)를 함께 쓰므로 한 번 로그인하면 시청·댓글·장작 넣기 창도 로그인된 채로 열린다.
 */
import { el } from "./dom";

export interface HeaderHandlers {
  openWeb(url: string, title: string): void;
}

const LINKS = [
  { text: "로그인", path: "/login" },
  { text: "회원가입", path: "/signup" },
] as const;

export function renderHeaderActions(root: HTMLElement, apiBase: string, h: HeaderHandlers): void {
  root.replaceChildren(
    ...LINKS.map(({ text, path }) => {
      const button = el("button", { className: "ghost", text, attrs: { type: "button" } });
      button.addEventListener("click", () => h.openWeb(`${apiBase}${path}`, text));
      return button;
    }),
  );
}
