import { describe, expect, it } from "vitest";
import { formatTime } from "../src/format";

describe("formatTime", () => {
  it("UTC 시각을 서울 시각 yyyy-MM-dd HH:mm 으로(웹과 같은 형식)", () => {
    expect(formatTime("2026-11-22T01:03:00Z")).toBe("2026-11-22 10:03");
    expect(formatTime("2026-11-20T15:30:00.123456Z")).toBe("2026-11-21 00:30");
  });
});
