package kr.devcourse.chzzk.live;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** 화면에 보일 시청 인원("불가에 N명")과 정원. 화면을 그리는 순간의 값이라 실시간으로 바뀌지는 않는다. */
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

    /** 라이브 하나에 들어올 수 있는 시청자 수. */
    public int capacity() {
        return capacity;
    }
}
