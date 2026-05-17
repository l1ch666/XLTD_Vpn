package com.s1dechain.olcrtcvpn;

public final class OlcUriParserContractTest {
    private static final String KEY = "d823fa01cb3e0609b67322f7cf984c4ee2e4ce2e294936fc24ef38c9e59f4799";

    public static void main(String[] args) {
        parsesUniversalCarrierUriWithoutClientId();
        parsesLegacyClientIdTail();
        usesClientIdTransportParam();
        acceptsAliasesAndJazzEmptyRoom();
        rejectsBadKey();
        System.out.println("OlcUriParserContractTest OK");
    }

    private static void parsesUniversalCarrierUriWithoutClientId() {
        OlcConfig config = OlcUriParser.parse(
                "olcrtc://telemost?vp8channel<vp8-fps=60&vp8-batch=64&tcp-limit=2&mtu=1040>@25000437143020#"
                        + KEY
                        + "$telemost-vp8"
        );

        assertEquals("carrier", "telemost", config.carrier);
        assertEquals("transport", OlcUriParser.TRANSPORT_VP8, config.transport);
        assertEquals("roomId", "25000437143020", config.roomId);
        assertEquals("clientId", "default", config.clientId);
        assertEquals("comment", "telemost-vp8", config.comment);
        assertEquals("vp8-fps", "60", config.param("vp8-fps", ""));
        assertEquals("vp8-batch", 64, config.intParam("vp8-batch", 0));
        assertEquals("tcp-limit", 2, config.intParam("tcp-limit", 0));
        assertEquals("mtu", 1040, config.intParam("mtu", 0));
    }

    private static void parsesLegacyClientIdTail() {
        OlcConfig config = OlcUriParser.parse(
                "olcrtc://wbstream?datachannel@room-01#" + KEY + "%android-client$direct"
        );

        assertEquals("carrier", "wbstream", config.carrier);
        assertEquals("transport", OlcUriParser.TRANSPORT_DATA, config.transport);
        assertEquals("clientId", "android-client", config.clientId);
        assertEquals("comment", "direct", config.comment);
    }

    private static void usesClientIdTransportParam() {
        OlcConfig config = OlcUriParser.parse(
                "olcrtc://telemost?seichannel<fps=60&batch=64&frag=900&ack-ms=2000&client-id=phone>@room-02#"
                        + KEY
                        + "$sei"
        );

        assertEquals("transport", OlcUriParser.TRANSPORT_SEI, config.transport);
        assertEquals("clientId", "phone", config.clientId);
        assertEquals("ack-ms", 2000, config.intParam("ack-ms", 0));
    }

    private static void acceptsAliasesAndJazzEmptyRoom() {
        OlcConfig config = OlcUriParser.parse(
                "olcrtc://jazz?video<video-w=1080&video-h=1080>@#" + KEY + "$jazz-video"
        );

        assertEquals("carrier", "jazz", config.carrier);
        assertEquals("transport", OlcUriParser.TRANSPORT_VIDEO, config.transport);
        assertEquals("roomId", "", config.roomId);
        assertEquals("video-w", 1080, config.intParam("video-w", 0));
    }

    private static void rejectsBadKey() {
        expectFailure(
                "bad key",
                () -> OlcUriParser.parse("olcrtc://telemost?vp8@room#not-a-hex-key$bad")
        );
    }

    private static void expectFailure(String name, ThrowingRunnable block) {
        try {
            block.run();
        } catch (IllegalArgumentException expected) {
            return;
        } catch (Exception e) {
            throw new AssertionError(name + ": wrong exception " + e, e);
        }
        throw new AssertionError(name + ": expected failure");
    }

    private static void assertEquals(String name, Object expected, Object actual) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(name + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }

    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
