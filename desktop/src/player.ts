/** 녹화방송 플레이어: 앱 안에서 playbackUrl 을 재생한다(탐색은 서버의 Range 206). 댓글·장작 넣기는 웹 화면에서. */
import type { RecordedItem } from "./api";
import { el } from "./dom";
import { formatTime } from "./format";

export interface PlayerHandlers {
  onBack(): void;
  onOpenWeb(item: RecordedItem): void;
  onOpenInBrowser(item: RecordedItem): void;
}

function button(text: string, className: string, onClick: () => void): HTMLButtonElement {
  const node = el("button", { className, text, attrs: { type: "button" } });
  node.addEventListener("click", onClick);
  return node;
}

export function renderPlayer(root: HTMLElement, item: RecordedItem, h: PlayerHandlers): void {
  const video = el("video", { className: "player", attrs: { src: item.playbackUrl, preload: "metadata" } });
  video.controls = true;
  video.playsInline = true;
  const notice = el("p", { className: "status error", attrs: { hidden: "" } });
  video.addEventListener("error", () => {
    notice.textContent = "영상을 재생하지 못했습니다. 웹에서 열어 보거나 잠시 뒤 다시 시도해 주세요.";
    notice.removeAttribute("hidden");
  });
  root.replaceChildren(
    el("section", { className: "player-view" }, [
      button("← 목록으로", "ghost", () => h.onBack()),
      video,
      notice,
      el("h1", { text: item.title }),
      el("p", {
        className: "card-meta",
        text: `${item.ownerNickname ?? "알 수 없는 방송자"} · ${formatTime(item.registeredAt)}`,
      }),
      el("div", { className: "actions" }, [
        button("댓글·장작 넣기는 웹에서", "primary", () => h.onOpenWeb(item)),
        button("브라우저로 열기", "link", () => h.onOpenInBrowser(item)),
      ]),
    ]),
  );
}
