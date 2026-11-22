import { describe, expect, it, vi } from "vitest";
import { ApiError, fetchBroadcasts, parseBroadcastList } from "../src/api";
import { sampleResponse } from "./fixtures";

describe("parseBroadcastList", () => {
  it("계약 모양의 응답을 그대로 읽는다", () => {
    const list = parseBroadcastList(sampleResponse);
    expect(list.live).toHaveLength(2);
    expect(list.live[0]).toEqual(sampleResponse.live[0]);
    expect(list.recorded[1].videoSource).toBe("EXTERNAL");
  });

  it("모르는 필드는 버리고 아는 필드만 남긴다", () => {
    const withExtra = structuredClone(sampleResponse) as Record<string, any>;
    withExtra.extra = 1;
    withExtra.recorded[0].thumbnailUrl = "https://x/y.png";
    const list = parseBroadcastList(withExtra);
    expect(list.recorded[0]).not.toHaveProperty("thumbnailUrl");
    expect(list).not.toHaveProperty("extra");
  });

  it("필수 필드가 없거나 타입이 다르면 ApiError", () => {
    const missing = structuredClone(sampleResponse) as Record<string, any>;
    delete missing.recorded[0].playbackUrl;
    expect(() => parseBroadcastList(missing)).toThrow(ApiError);
    expect(() => parseBroadcastList({ live: "x", recorded: [] })).toThrow(ApiError);
    expect(() => parseBroadcastList(null)).toThrow(ApiError);
  });
});

describe("fetchBroadcasts", () => {
  it("서버 주소 뒤에 /api/broadcasts 를 붙여 부르고 응답을 읽는다", async () => {
    const fetchImpl = vi.fn(async () => new Response(JSON.stringify(sampleResponse), { status: 200 }));
    const list = await fetchBroadcasts("https://tadak.example.test", fetchImpl);
    expect(fetchImpl).toHaveBeenCalledWith("https://tadak.example.test/api/broadcasts", expect.anything());
    expect(list.recorded[0].title).toBe("첫 녹화");
  });

  it("서버가 오류 코드를 주면 한국어 안내가 담긴 ApiError", async () => {
    const fetchImpl = vi.fn(async () => new Response("nope", { status: 502 }));
    await expect(fetchBroadcasts("https://tadak.example.test", fetchImpl)).rejects.toThrow(/502/);
  });

  it("네트워크 실패도 ApiError", async () => {
    const fetchImpl = vi.fn(async () => { throw new TypeError("Failed to fetch"); });
    await expect(fetchBroadcasts("https://tadak.example.test", fetchImpl)).rejects.toBeInstanceOf(ApiError);
  });
});
