package kr.devcourse.chzzk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.jayway.jsonpath.JsonPath;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.context.WebApplicationContext;

/**
 * 데스크톱 앱 등 클라이언트용 방송 목록 API(GET /api/broadcasts). 비로그인 공개, 웹 목록과 같은 범위·순서,
 * 앱이 서버 밖에서 쓰도록 재생·시청 주소는 요청(프록시 헤더) 기준 절대 주소. 회원 DB id·로그인 아이디는 넣지 않는다.
 * 테스트끼리 한 서버·DB를 쓰므로 각 테스트는 자기가 만든 방송(고유 제목)만 골라 확인한다. 빈 목록은 {@link BroadcastListApiEmptyTest}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BroadcastListApiTest {

    @TempDir
    static Path dataDir;

    @DynamicPropertySource
    static void dataDir(DynamicPropertyRegistry registry) {
        registry.add("chzzk.data-dir", dataDir::toString);
    }

    private static final HttpClient CLIENT = HttpClient.newHttpClient();

    @LocalServerPort
    int port;

    @Autowired
    WebApplicationContext context;

    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = TestWeb.mvc(context);
    }

    HttpResponse<String> getApi(String... headers) throws Exception {
        HttpRequest.Builder request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/broadcasts"));
        if (headers.length > 0) {
            request.headers(headers);
        }
        return CLIENT.send(request.GET().build(), HttpResponse.BodyHandlers.ofString());
    }

    /** 이 테스트가 만든 항목만(제목이 tag 로 시작) 응답 순서대로. */
    static List<Map<String, Object>> mine(String body, String list, String tag) {
        List<Map<String, Object>> items = JsonPath.read(body, "$." + list);
        return items.stream().filter(item -> ((String) item.get("title")).startsWith(tag)).toList();
    }

    String registerExternal(MockHttpSession owner, String title, String url) throws Exception {
        return mvc.perform(multipart("/broadcasts").session(owner).param("title", title).param("videoUrl", url))
                .andReturn().getResponse().getRedirectedUrl();
    }

    String registerUpload(MockHttpSession owner, String title) throws Exception {
        return mvc.perform(multipart("/broadcasts").session(owner).param("title", title)
                        .file(new MockMultipartFile("videoFile", "clip.mp4", "video/mp4", new byte[] {1, 2, 3})))
                .andReturn().getResponse().getRedirectedUrl();
    }

    Long startLive(MockHttpSession owner, String title) throws Exception {
        String body = mvc.perform(post("/live").session(owner).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"" + title + "\"}"))
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.id")).longValue();
    }

    @Test
    void 녹화방송은_최신순이고_업로드는_서버_재생_주소_외부는_등록_주소를_준다() throws Exception {
        MockHttpSession owner = MemberSessions.signUpAs(mvc, "타닥이");
        String externalPath = registerExternal(owner, "녹화순서 외부 영상", "https://cdn.example.com/vod/a.mp4");
        Thread.sleep(5);
        String uploadPath = registerUpload(owner, "녹화순서 올린 영상");

        String body = getApi().body();
        String base = "http://localhost:" + port;

        List<Map<String, Object>> recorded = mine(body, "recorded", "녹화순서 ");
        assertThat(recorded).hasSize(2);

        Map<String, Object> upload = recorded.get(0);
        assertThat(upload.get("title")).isEqualTo("녹화순서 올린 영상");
        assertThat(upload.get("ownerNickname")).isEqualTo("타닥이");
        assertThat(upload.get("videoSource")).isEqualTo("UPLOADED");
        assertThat((String) upload.get("playbackUrl")).startsWith(base + "/videos/").endsWith(".mp4");
        assertThat(upload.get("watchUrl")).isEqualTo(base + uploadPath);
        assertThat(upload.get("id")).isEqualTo(Integer.valueOf(uploadPath.substring(uploadPath.lastIndexOf('/') + 1)));
        assertThat((String) upload.get("registeredAt")).matches("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?Z");

        Map<String, Object> external = recorded.get(1);
        assertThat(external.get("title")).isEqualTo("녹화순서 외부 영상");
        assertThat(external.get("videoSource")).isEqualTo("EXTERNAL");
        assertThat(external.get("playbackUrl")).isEqualTo("https://cdn.example.com/vod/a.mp4");
        assertThat(external.get("watchUrl")).isEqualTo(base + externalPath);
    }

    @Test
    void 라이브는_방송_중이_먼저이고_시청_주소와_상태_시각을_준다() throws Exception {
        MockHttpSession first = MemberSessions.signUpAs(mvc, "먼저켠사람");
        MockHttpSession second = MemberSessions.signUpAs(mvc, "나중켠사람");
        Long endedId = startLive(first, "라이브순서 끝난 라이브");
        mvc.perform(post("/live/" + endedId + "/end").session(first));
        Long onAirId = startLive(second, "라이브순서 타는 중인 라이브");

        String body = getApi().body();

        List<Map<String, Object>> live = mine(body, "live", "라이브순서 ");
        assertThat(live).extracting(item -> item.get("id")).containsExactly(onAirId.intValue(), endedId.intValue());

        Map<String, Object> onAir = live.get(0);
        assertThat(onAir.get("title")).isEqualTo("라이브순서 타는 중인 라이브");
        assertThat(onAir.get("ownerNickname")).isEqualTo("나중켠사람");
        assertThat(onAir.get("status")).isEqualTo("ON_AIR");
        assertThat((String) onAir.get("startedAt")).endsWith("Z");
        assertThat(onAir.get("endedAt")).isNull();
        assertThat(onAir.get("watchUrl")).isEqualTo("http://localhost:" + port + "/live/" + onAirId);

        Map<String, Object> ended = live.get(1);
        assertThat(ended.get("status")).isEqualTo("ENDED");
        assertThat((String) ended.get("endedAt")).endsWith("Z");
    }

    @Test
    void 프록시_헤더가_있으면_재생_시청_주소가_https_공개_주소다() throws Exception {
        MockHttpSession owner = MemberSessions.signUpAs(mvc, "타닥이");
        registerUpload(owner, "프록시 올린 영상");
        startLive(owner, "프록시 라이브");

        String body = getApi("X-Forwarded-Proto", "https", "X-Forwarded-Host", "tadak.example.test").body();

        Map<String, Object> recorded = mine(body, "recorded", "프록시 ").get(0);
        Map<String, Object> live = mine(body, "live", "프록시 ").get(0);
        assertThat((String) recorded.get("playbackUrl")).startsWith("https://tadak.example.test/videos/");
        assertThat((String) recorded.get("watchUrl")).startsWith("https://tadak.example.test/broadcasts/");
        assertThat((String) live.get("watchUrl")).startsWith("https://tadak.example.test/live/");
    }

    @Test
    void 응답에_회원_id와_로그인_아이디가_없다() throws Exception {
        MockHttpSession owner = MemberSessions.signUpAs(mvc, "타닥이");
        registerUpload(owner, "비공개확인 올린 영상");
        startLive(owner, "비공개확인 라이브");

        String body = getApi().body();

        assertThat(body).doesNotContain("loginId", "ownerId", "memberId", "\"owner\"", "password");
        assertThat(mine(body, "recorded", "비공개확인 ").get(0)).containsOnlyKeys(
                "id", "title", "ownerNickname", "registeredAt", "videoSource", "playbackUrl", "watchUrl");
    }
}
