package kr.devcourse.chzzk;

import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * GET /api/broadcasts 의 라이브 시청자 수: 방송 중이면 지금 붙은 시청자 수와 정원, 종료되면 0.
 * 시그널링(WebSocket)이 실제 세션 쿠키를 쓰므로 MockMvc 없이 실제 HTTP만 쓴다. 테스트에서는 정원을 3으로 둔다.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BroadcastListApiViewerTest {

    @TempDir
    static Path dataDir;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("chzzk.data-dir", dataDir::toString);
        registry.add("chzzk.live.viewer-capacity", () -> "3");
    }

    @LocalServerPort
    int port;

    Map<String, Object> liveItem(String liveId) throws Exception {
        String body = TestLogin.Http.anonymous(port).get("/api/broadcasts").body();
        List<Map<String, Object>> live = JsonPath.read(body, "$.live[?(@.id == " + liveId + ")]");
        return live.get(0);
    }

    @Test
    void 방송_중_라이브는_지금_붙은_시청자_수와_정원을_주고_종료되면_0이다() throws Exception {
        TestLogin.Http owner = TestLogin.member(port);
        String liveId = owner.startedLiveId("시청자수 라이브");

        try (SignalingClient broadcaster = SignalingClient.broadcaster(port, liveId, owner)) {
            assertThat(liveItem(liveId).get("viewerCount")).isEqualTo(0);

            try (SignalingClient viewer = SignalingClient.connect("ws://localhost:" + port + "/ws/live/" + liveId + "/viewer")) {
                assertThat((String) broadcaster.next("$.type")).isEqualTo("viewer-joined");
                Map<String, Object> live = liveItem(liveId);
                assertThat(live.get("status")).isEqualTo("ON_AIR");
                assertThat(live.get("viewerCount")).isEqualTo(1);
                assertThat(live.get("viewerCapacity")).isEqualTo(3);
            }
            assertThat((String) broadcaster.next("$.type")).isEqualTo("viewer-left");
            assertThat(liveItem(liveId).get("viewerCount")).isEqualTo(0);
        }

        assertThat(owner.post("/live/" + liveId + "/end").statusCode()).isLessThan(400);
        Map<String, Object> ended = liveItem(liveId);
        assertThat(ended.get("status")).isEqualTo("ENDED");
        assertThat(ended.get("viewerCount")).isEqualTo(0);
        assertThat(ended.get("viewerCapacity")).isEqualTo(3);
    }
}
