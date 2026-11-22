package kr.devcourse.chzzk.list;

import java.time.Instant;
import java.util.List;
import kr.devcourse.chzzk.broadcast.RecordedBroadcast;
import kr.devcourse.chzzk.broadcast.RecordedBroadcastService;
import kr.devcourse.chzzk.broadcast.VideoSource;
import kr.devcourse.chzzk.live.LiveBroadcast;
import kr.devcourse.chzzk.live.LiveBroadcastService;
import kr.devcourse.chzzk.live.LiveStatus;
import kr.devcourse.chzzk.member.Member;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * 데스크톱 앱 등 클라이언트용 방송 목록(비로그인 공개, 읽기 전용). 범위·순서는 웹 목록(/broadcasts)과 같다.
 * 클라이언트가 서버 밖에서 쓰므로 재생·시청 주소는 요청 기준 절대 주소다(프록시 뒤에서는 X-Forwarded-* 로 https 공개 주소).
 * 응답 필드는 추가만 하고 바꾸거나 지우지 않는다. 회원 DB id·로그인 아이디는 넣지 않는다. 계약: SPEC-broadcast-api.md
 */
@RestController
class BroadcastListApiController {

    record BroadcastList(List<LiveItem> live, List<RecordedItem> recorded) {
    }

    record LiveItem(Long id, String title, String ownerNickname, LiveStatus status,
                    Instant startedAt, Instant endedAt, String watchUrl) {
    }

    record RecordedItem(Long id, String title, String ownerNickname, Instant registeredAt,
                        VideoSource videoSource, String playbackUrl, String watchUrl) {
    }

    private final LiveBroadcastService liveBroadcasts;
    private final RecordedBroadcastService recordedBroadcasts;

    BroadcastListApiController(LiveBroadcastService liveBroadcasts, RecordedBroadcastService recordedBroadcasts) {
        this.liveBroadcasts = liveBroadcasts;
        this.recordedBroadcasts = recordedBroadcasts;
    }

    @GetMapping("/api/broadcasts")
    BroadcastList list() {
        List<LiveItem> live = liveBroadcasts.list().stream().map(this::toItem).toList();
        List<RecordedItem> recorded = recordedBroadcasts.list().stream().map(this::toItem).toList();
        return new BroadcastList(live, recorded);
    }

    private LiveItem toItem(LiveBroadcast live) {
        return new LiveItem(live.getId(), live.getTitle(), nicknameOf(live.getOwner()), live.getStatus(),
                live.getStartedAt(), live.getEndedAt(), absolute("/live/" + live.getId()));
    }

    private RecordedItem toItem(RecordedBroadcast broadcast) {
        String playbackUrl = broadcast.getVideoSource() == VideoSource.UPLOADED
                ? absolute(broadcast.playbackUrl())
                : broadcast.playbackUrl();
        return new RecordedItem(broadcast.getId(), broadcast.getTitle(), nicknameOf(broadcast.getOwner()),
                broadcast.getRegisteredAt(), broadcast.getVideoSource(), playbackUrl,
                absolute("/broadcasts/" + broadcast.getId()));
    }

    private static String nicknameOf(Member owner) {
        return owner == null ? null : owner.getNickname();
    }

    /** 현재 요청의 scheme·host(프록시 헤더 반영) 기준 절대 주소. */
    private static String absolute(String path) {
        return ServletUriComponentsBuilder.fromCurrentContextPath().path(path).toUriString();
    }
}
