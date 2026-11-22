package kr.devcourse.chzzk.live;

/** 방송 상태. 방송 중에서 종료로만 바뀐다. 화면 이름(label)은 모닥불 말투(타는 중 / 불 꺼짐)를 쓴다. */
public enum LiveStatus {
    /** 시작되어 시청할 수 있다. */
    ON_AIR("타는 중"),
    /** 끝났다. 다시 방송 중이 될 수 없다. */
    ENDED("불 꺼짐");

    private final String label;

    LiveStatus(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}
