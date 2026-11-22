/** 서버 /api/broadcasts 응답 예시(계약: SPEC-broadcast-api.md). */
export const sampleResponse = {
  live: [
    {
      id: 3, title: "저녁 산책 라이브", ownerNickname: "타닥이", status: "ON_AIR",
      startedAt: "2026-11-22T10:20:00Z", endedAt: null, viewerCount: 2, viewerCapacity: 5,
      watchUrl: "https://tadak.example.test/live/3",
    },
    {
      id: 1, title: "끝난 라이브", ownerNickname: null, status: "ENDED",
      startedAt: "2026-11-21T09:00:00Z", endedAt: "2026-11-21T10:00:00Z", viewerCount: 0, viewerCapacity: 5,
      watchUrl: "https://tadak.example.test/live/1",
    },
  ],
  recorded: [
    {
      id: 2, title: "첫 녹화", ownerNickname: "타닥이", registeredAt: "2026-11-22T01:03:00Z",
      videoSource: "UPLOADED", playbackUrl: "https://tadak.example.test/videos/a.mp4",
      watchUrl: "https://tadak.example.test/broadcasts/2",
    },
    {
      id: 1, title: "외부 영상", ownerNickname: "다른이", registeredAt: "2026-11-20T15:30:00Z",
      videoSource: "EXTERNAL", playbackUrl: "https://cdn.example.com/b.mp4",
      watchUrl: "https://tadak.example.test/broadcasts/1",
    },
  ],
};
