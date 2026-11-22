/**
 * 상단 오른쪽 버튼. 앱에는 자체 로그인 화면이 없고(의도 문서), 웹 로그인 화면(/login)을 앱 안 창으로 연다.
 * 앱의 웹 창들은 로그인 상태(쿠키)를 함께 쓰므로 한 번 로그인하면 시청·댓글·장작 넣기 창도 로그인된 채로 열린다.
 */
import { el } from "./dom";

export interface HeaderHandlers {
  openLogin(url: string): void;
}

export function renderHeaderActions(root: HTMLElement, apiBase: string, h: HeaderHandlers): void {
  const login = el("button", { className: "ghost", text: "로그인", attrs: { type: "button" } });
  login.addEventListener("click", () => h.openLogin(`${apiBase}/login`));
  root.replaceChildren(login);
}
