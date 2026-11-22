import { describe, expect, it } from "vitest";
import { APP_TITLE } from "../src/main";

describe("앱 뼈대", () => {
  it("창 제목은 타닥 라이브", () => {
    expect(APP_TITLE).toBe("타닥 라이브");
  });
});
