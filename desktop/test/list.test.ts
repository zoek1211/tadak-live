import { beforeEach, describe, expect, it, vi } from "vitest";
import { parseBroadcastList } from "../src/api";
import { onAirLives, renderList } from "../src/list";
import { sampleResponse } from "./fixtures";

const handlers = () => ({ onOpenLive: vi.fn(), onOpenLiveInBrowser: vi.fn(), onOpenRecorded: vi.fn(), onRetry: vi.fn() });

describe("onAirLives", () => {
  it("방송 중인 라이브만 남긴다(종료는 앱에서 볼 게 없음)", () => {
    const lives = onAirLives(parseBroadcastList(sampleResponse));
    expect(lives.map((l) => l.id)).toEqual([3]);
  });
});

describe("renderList", () => {
  let root: HTMLElement;
  beforeEach(() => {
    root = document.createElement("div");
  });

  it("지금 타는 중과 다시 보기 두 줄을 그리고 라이브에 불가에 N명을 쓴다", () => {
    renderList(root, { kind: "ok", data: parseBroadcastList(sampleResponse) }, handlers());
    const headings = [...root.querySelectorAll("h2")].map((h) => h.textContent);
    expect(headings).toEqual(["지금 타는 중", "다시 보기"]);
    const live = root.querySelectorAll("[data-live-id]");
    expect(live).toHaveLength(1);
    expect(live[0].textContent).toContain("저녁 산책 라이브");
    expect(live[0].textContent).toContain("불가에 2명");
    const recorded = [...root.querySelectorAll("[data-recorded-id]")];
    expect(recorded.map((el) => el.getAttribute("data-recorded-id"))).toEqual(["2", "1"]);
    expect(recorded[0].textContent).toContain("2026-11-22 10:03");
    expect(recorded[0].textContent).toContain("타닥이");
  });

  it("카드를 누르면 해당 방송으로 처리기를 부른다", () => {
    const h = handlers();
    renderList(root, { kind: "ok", data: parseBroadcastList(sampleResponse) }, h);
    (root.querySelector("[data-live-id='3']") as HTMLElement).click();
    (root.querySelector("[data-recorded-id='1']") as HTMLElement).click();
    expect(h.onOpenLive).toHaveBeenCalledWith(expect.objectContaining({ id: 3 }));
    expect(h.onOpenRecorded).toHaveBeenCalledWith(expect.objectContaining({ id: 1 }));
  });

  it("라이브마다 브라우저로 열기 버튼이 있고 누르면 그 라이브로 처리기를 부른다", () => {
    const h = handlers();
    renderList(root, { kind: "ok", data: parseBroadcastList(sampleResponse) }, h);
    const browser = [...root.querySelectorAll("button")].find((b) => b.textContent === "브라우저로 열기")!;
    browser.click();
    expect(h.onOpenLiveInBrowser).toHaveBeenCalledWith(expect.objectContaining({ id: 3 }));
    expect(h.onOpenLive).not.toHaveBeenCalled();
  });

  it("제목에 HTML을 넣어도 글자로 보인다", () => {
    const data = parseBroadcastList(sampleResponse);
    data.recorded[0].title = "<img src=x onerror=alert(1)>위험";
    renderList(root, { kind: "ok", data }, handlers());
    expect(root.querySelector("img")).toBeNull();
    expect(root.textContent).toContain("<img src=x onerror=alert(1)>위험");
  });

  it("방송이 없으면 줄마다 안내를 쓴다", () => {
    renderList(root, { kind: "ok", data: { live: [], recorded: [] } }, handlers());
    expect(root.textContent).toContain("지금 타는 방송이 없습니다");
    expect(root.textContent).toContain("다시 볼 방송이 없습니다");
  });

  it("불러오지 못하면 안내와 다시 시도 버튼, 누르면 onRetry", () => {
    const h = handlers();
    renderList(root, { kind: "error", message: "서버에 연결하지 못했습니다." }, h);
    expect(root.textContent).toContain("서버에 연결하지 못했습니다.");
    const retry = [...root.querySelectorAll("button")].find((b) => b.textContent === "다시 시도");
    retry!.click();
    expect(h.onRetry).toHaveBeenCalled();
  });

  it("처음 불러오는 중에는 불러오는 중 안내", () => {
    renderList(root, { kind: "loading" }, handlers());
    expect(root.textContent).toContain("불러오는 중");
  });
});
