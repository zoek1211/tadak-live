package kr.devcourse.chzzk.live;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 라이브 방송의 시청 인원과 정원. 화면("불가에 N명", 템플릿에서 {@code @liveAudience})과 목록 API가 함께 쓴다.
 * 단독·클러스터 모드 모두 {@link LiveRooms} 가 센다. 묻는 순간의 값이라 실시간으로 바뀌지는 않는다.
 * LiveRooms 가 LiveBroadcastService 에 기대므로 순환을 피하려고 서비스와 따로 둔다.
 */
@Component
public class LiveAudience {

    private final LiveRooms rooms;
    private final int capacity;

    LiveAudience(LiveRooms rooms, @Value("${chzzk.live.viewer-capacity:5}") int capacity) {
        this.rooms = rooms;
        this.capacity = capacity;
    }

    /** 지금 그 라이브를 보고 있는 시청자 수. */
    public int count(Long liveId) {
        return rooms.viewerIds(liveId).size();
    }

    /** 지금 붙어 있는 시청자 수. 방송 중이 아니면 0. */
    public int count(LiveBroadcast live) {
        return live.isOnAir() ? count(live.getId()) : 0;
    }

    /** 라이브 하나에 들어올 수 있는 시청자 수. */
    public int capacity() {
        return capacity;
    }
}
