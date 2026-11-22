import { describe, expect, it, vi } from "vitest";
import { parseBroadcastList } from "../src/api";
import { renderPlayer } from "../src/player";
import { sampleResponse } from "./fixtures";

const item = (i: number) => parseBroadcastList(sampleResponse).recorded[i];

describe("renderPlayer", () => {
  it("제목·방송한 사람·등록 시각과 영상(재생 주소, 조작 막대)을 그린다", () => {
    const root = document.createElement("div");
    renderPlayer(root, item(0), { onBack: vi.fn(), onOpenWeb: vi.fn(), onOpenInBrowser: vi.fn() });
    expect(root.querySelector("h1")!.textContent).toBe("첫 녹화");
    expect(root.textContent).toContain("타닥이 · 2026-11-22 10:03");
    const video = root.querySelector("video")!;
    expect(video.getAttribute("src")).toBe("https://tadak.example.test/videos/a.mp4");
    expect(video.controls).toBe(true);
  });

  it("외부 영상도 등록된 주소로 같은 플레이어에서 재생한다", () => {
    const root = document.createElement("div");
    renderPlayer(root, item(1), { onBack: vi.fn(), onOpenWeb: vi.fn(), onOpenInBrowser: vi.fn() });
    expect(root.querySelector("video")!.getAttribute("src")).toBe("https://cdn.example.com/b.mp4");
  });

  it("목록으로·웹에서 열기 버튼이 처리기를 부른다", () => {
    const root = document.createElement("div");
    const h = { onBack: vi.fn(), onOpenWeb: vi.fn(), onOpenInBrowser: vi.fn() };
    renderPlayer(root, item(0), h);
    const button = (text: string) => [...root.querySelectorAll("button")].find((b) => b.textContent === text)!;
    button("← 목록으로").click();
    button("댓글·장작 넣기는 웹에서").click();
    button("브라우저로 열기").click();
    expect(h.onBack).toHaveBeenCalled();
    expect(h.onOpenWeb).toHaveBeenCalledWith(expect.objectContaining({ id: 2 }));
    expect(h.onOpenInBrowser).toHaveBeenCalledWith(expect.objectContaining({ id: 2 }));
  });

  it("영상을 재생하지 못하면 안내를 보인다", () => {
    const root = document.createElement("div");
    renderPlayer(root, item(0), { onBack: vi.fn(), onOpenWeb: vi.fn(), onOpenInBrowser: vi.fn() });
    root.querySelector("video")!.dispatchEvent(new Event("error"));
    expect(root.textContent).toContain("영상을 재생하지 못했습니다");
  });
});
