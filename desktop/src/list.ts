/** 목록 화면: 웹 홈과 같은 "지금 타는 중"(방송 중 라이브)·"다시 보기"(녹화방송) 두 줄. */
import type { BroadcastList, LiveItem, RecordedItem } from "./api";
import { el } from "./dom";
import { formatTime } from "./format";

export type ListState =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "ok"; data: BroadcastList };

export interface ListHandlers {
  onOpenLive(item: LiveItem): void;
  onOpenLiveInBrowser(item: LiveItem): void;
  onOpenRecorded(item: RecordedItem): void;
  onRetry(): void;
}

/** 앱에서는 방송 중인 라이브만 보인다(종료된 라이브는 볼 게 없다). */
export function onAirLives(list: BroadcastList): LiveItem[] {
  return list.live.filter((l) => l.status === "ON_AIR");
}

function card(onClick: () => void, attrs: Record<string, string>, children: Node[]): HTMLElement {
  const node = el("button", { className: "card", attrs: { type: "button", ...attrs } }, children);
  node.addEventListener("click", onClick);
  return node;
}

function liveCard(item: LiveItem, h: ListHandlers): HTMLElement {
  const main = card(() => h.onOpenLive(item), { "data-live-id": String(item.id) }, [
    el("div", { className: "thumb" }, [
      el("span", { className: "badge live", text: "타는 중" }),
      el("span", { className: "chip", text: `불가에 ${item.viewerCount}명` }),
    ]),
    el("div", { className: "card-title", text: item.title }),
    el("div", { className: "card-meta", text: item.ownerNickname ?? "알 수 없는 방송자" }),
  ]);
  // 앱 안 웹 창에서 막히는 경우(결제 팝업 등)를 위한 우회
  const browser = el("button", { className: "link", text: "브라우저로 열기", attrs: { type: "button" } });
  browser.addEventListener("click", () => h.onOpenLiveInBrowser(item));
  return el("div", { className: "card-wrap" }, [main, browser]);
}

function recordedCard(item: RecordedItem, h: ListHandlers): HTMLElement {
  return card(() => h.onOpenRecorded(item), { "data-recorded-id": String(item.id) }, [
    el("div", { className: "thumb" }, [el("span", { className: "chip", text: "다시 보기" })]),
    el("div", { className: "card-title", text: item.title }),
    el("div", {
      className: "card-meta",
      text: `${item.ownerNickname ?? "알 수 없는 방송자"} · ${formatTime(item.registeredAt)}`,
    }),
  ]);
}

function row(title: string, cards: HTMLElement[], empty: string): HTMLElement {
  return el("section", { className: "row" }, [
    el("h2", { text: title }),
    cards.length > 0 ? el("div", { className: "cards" }, cards) : el("p", { className: "empty", text: empty }),
  ]);
}

export function renderList(root: HTMLElement, state: ListState, h: ListHandlers): void {
  if (state.kind === "loading") {
    root.replaceChildren(el("p", { className: "status", text: "방송 목록을 불러오는 중입니다…" }));
    return;
  }
  if (state.kind === "error") {
    const retry = el("button", { className: "primary", text: "다시 시도", attrs: { type: "button" } });
    retry.addEventListener("click", () => h.onRetry());
    root.replaceChildren(el("div", { className: "status error" }, [el("p", { text: state.message }), retry]));
    return;
  }
  root.replaceChildren(
    row("지금 타는 중", onAirLives(state.data).map((l) => liveCard(l, h)), "지금 타는 방송이 없습니다."),
    row("다시 보기", state.data.recorded.map((r) => recordedCard(r, h)), "다시 볼 방송이 없습니다."),
  );
}
