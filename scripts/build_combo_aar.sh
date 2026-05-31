#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXT="${PROJECT_ROOT}/.external"
OLC_DIR="${EXT}/olcrtc"
TUN_DIR="${EXT}/tun2socks"
COMBO_DIR="${EXT}/olcrtccombo"
OUT_AAR="${PROJECT_ROOT}/app/libs/olcrtccombo.aar"
ANDROID_FFMPEG_VERSION="${ANDROID_FFMPEG_VERSION:-8.1}"
ANDROID_FFMPEG_ABIS="${ANDROID_FFMPEG_ABIS:-arm64-v8a}"
ANDROID_FFMPEG_ASSETS_DIR="${PROJECT_ROOT}/app/src/main/assets/ffmpeg"
ANDROID_FFMPEG_CACHE_DIR="${EXT}/ffmpeg-android"
OLC_REPO="${OLC_REPO:-https://github.com/openlibrecommunity/olcrtc.git}"
OLC_REF="${OLC_REF:-fix/jitsi-nonblocking-connect}"
OLC_PATCHES="${OLC_PATCHES:-}"

mkdir -p "${EXT}" "${PROJECT_ROOT}/app/libs"

clone_olcrtc() {
  if [ ! -d "${OLC_DIR}/.git" ]; then
    echo "Cloning olcRTC ref ${OLC_REF} from ${OLC_REPO}..."
    git clone --branch "${OLC_REF}" --recurse-submodules "${OLC_REPO}" "${OLC_DIR}"
  else
    echo "Using existing olcRTC tree; trying to switch to ${OLC_REF} from ${OLC_REPO}."
    (
      cd "${OLC_DIR}"
      current_url="$(git remote get-url origin 2>/dev/null || true)"
      if [ "${current_url}" != "${OLC_REPO}" ]; then
        git remote set-url origin "${OLC_REPO}"
      fi
      if git fetch origin "${OLC_REF}"; then
        if git show-ref --verify --quiet "refs/heads/${OLC_REF}"; then
          git checkout "${OLC_REF}"
        else
          git checkout -b "${OLC_REF}" "origin/${OLC_REF}"
        fi
        git pull --ff-only origin "${OLC_REF}" || true
        git submodule update --init --recursive || true
      else
        echo "WARN: git fetch failed; using existing olcRTC checkout as-is."
      fi
    )
  fi
}

clone_if_missing() {
  local url="$1"
  local dir="$2"
  if [ ! -d "${dir}/.git" ]; then
    echo "Cloning ${url}..."
    git clone --recurse-submodules "${url}" "${dir}"
  else
    echo "Using existing ${dir}; skipping git pull to avoid network/DNS failures."
  fi
}

clone_olcrtc
clone_if_missing "https://github.com/xjasonlyu/tun2socks" "${TUN_DIR}"

apply_olcrtc_patch() {
  if [ -z "${OLC_PATCHES}" ]; then
    echo "No local olcRTC patch configured; using ${OLC_REPO}@${OLC_REF} as-is."
    return
  fi
  local patch
  for patch in ${OLC_PATCHES}; do
    if [ ! -f "${patch}" ]; then
      continue
    fi
    if git -C "${OLC_DIR}" apply --check "${patch}" >/dev/null 2>&1; then
      echo "Applying local olcRTC patch: ${patch}"
      git -C "${OLC_DIR}" apply "${patch}"
    elif git -C "${OLC_DIR}" apply --reverse --check --ignore-space-change --ignore-whitespace "${patch}" >/dev/null 2>&1; then
      echo "Local olcRTC patch already applied: ${patch}"
    else
      echo "ERROR: local olcRTC patch does not apply cleanly: ${patch}" >&2
      exit 1
    fi
  done
}

apply_olcrtc_patch

android_ffmpeg_arch() {
  case "$1" in
    arm64-v8a) echo "arm64" ;;
    armeabi-v7a) echo "arm" ;;
    x86_64) echo "x64" ;;
    x86) echo "x86" ;;
    *) echo "" ;;
  esac
}

extract_zip() {
  local zip="$1"
  local dest="$2"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$zip" -d "$dest"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -e "$zip" "$dest"
    return
  fi
  if command -v python >/dev/null 2>&1; then
    python -m zipfile -e "$zip" "$dest"
    return
  fi
  echo "[X] Need unzip or python to extract Android ffmpeg archive" >&2
  exit 1
}

prepare_android_ffmpeg_assets() {
  if [ "${ANDROID_FFMPEG:-1}" = "0" ]; then
    echo "[*] ANDROID_FFMPEG=0: skipping bundled Android ffmpeg asset"
    return
  fi

  mkdir -p "$ANDROID_FFMPEG_CACHE_DIR" "$ANDROID_FFMPEG_ASSETS_DIR"
  IFS=',' read -ra ABI_LIST <<< "$ANDROID_FFMPEG_ABIS"
  for abi in "${ABI_LIST[@]}"; do
    abi="$(echo "$abi" | xargs)"
    [ -n "$abi" ] || continue

    arch="$(android_ffmpeg_arch "$abi")"
    if [ -z "$arch" ]; then
      echo "[X] Unsupported Android ABI for ffmpeg asset: $abi" >&2
      exit 1
    fi

    target_dir="${ANDROID_FFMPEG_ASSETS_DIR}/${abi}"
    target="${target_dir}/ffmpeg"
    mkdir -p "$target_dir"

    if [ -n "${ANDROID_FFMPEG_DIR:-}" ] && [ -f "${ANDROID_FFMPEG_DIR}/${abi}/ffmpeg" ]; then
      cp "${ANDROID_FFMPEG_DIR}/${abi}/ffmpeg" "$target"
      chmod 0755 "$target"
      echo "[*] Bundled Android ffmpeg from ANDROID_FFMPEG_DIR for $abi"
      continue
    fi

    zip="${ANDROID_FFMPEG_CACHE_DIR}/ffmpeg-android-${arch}-${ANDROID_FFMPEG_VERSION}.zip"
    url="https://github.com/Tyrrrz/FFmpegBin/releases/download/${ANDROID_FFMPEG_VERSION}/ffmpeg-android-${arch}.zip"
    if [ ! -f "$zip" ]; then
      echo "[*] Downloading Android ffmpeg ${ANDROID_FFMPEG_VERSION} for $abi..."
      curl -L --fail --retry 3 -o "$zip" "$url"
    fi

    extract_dir="${ANDROID_FFMPEG_CACHE_DIR}/extract-${abi}"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    extract_zip "$zip" "$extract_dir"

    found="$(find "$extract_dir" -type f \( -name ffmpeg -o -name ffmpeg.exe \) | head -n 1)"
    if [ -z "$found" ]; then
      echo "[X] Android ffmpeg archive for $abi did not contain ffmpeg" >&2
      exit 1
    fi
    cp "$found" "$target"
    chmod 0755 "$target"
    echo "[*] Bundled Android ffmpeg asset: assets/ffmpeg/${abi}/ffmpeg"
  done
}

prepare_android_ffmpeg_assets

mkdir -p "${COMBO_DIR}"
cat > "${COMBO_DIR}/go.mod" <<'EOGO'
module github.com/openlibrecommunity/olcrtc/mobilecombo

go 1.26

require (
    github.com/openlibrecommunity/olcrtc v0.0.0
    github.com/xjasonlyu/tun2socks/v2 v2.6.0
)

replace github.com/openlibrecommunity/olcrtc => ../olcrtc
replace github.com/xjasonlyu/tun2socks/v2 => ../tun2socks
EOGO

cat > "${COMBO_DIR}/tools.go" <<'EOGO'
//go:build tools

package mobile

// Keep gomobile/gobind runtime packages in go.mod. The generated Java/Go
// bindings import golang.org/x/mobile/bind even though mobile.go itself does
// not, so plain `go mod tidy` can otherwise remove x/mobile and gobind fails.
import (
    _ "golang.org/x/mobile/bind"
)
EOGO

cat > "${COMBO_DIR}/mobile.go" <<'EOGO'
// Package mobile is a single gomobile bridge for both olcRTC and tun2socks.
// It intentionally generates Java class mobile.Mobile, so the Android app uses
// one AAR and avoids duplicate gomobile runtime classes.
package mobile

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/openlibrecommunity/olcrtc/internal/app/session"
	"github.com/openlibrecommunity/olcrtc/internal/client"
	"github.com/openlibrecommunity/olcrtc/internal/control"
	"github.com/openlibrecommunity/olcrtc/internal/logger"
	"github.com/openlibrecommunity/olcrtc/internal/protect"
	"github.com/openlibrecommunity/olcrtc/internal/transport"
	"github.com/openlibrecommunity/olcrtc/internal/transport/seichannel"
	"github.com/openlibrecommunity/olcrtc/internal/transport/videochannel"
	"github.com/openlibrecommunity/olcrtc/internal/transport/vp8channel"
	_ "github.com/xjasonlyu/tun2socks/v2/dns"
	"github.com/xjasonlyu/tun2socks/v2/engine"
	M "github.com/xjasonlyu/tun2socks/v2/metadata"
	"github.com/xjasonlyu/tun2socks/v2/proxy"
	"github.com/xjasonlyu/tun2socks/v2/tunnel"
)

// SocketProtector protects sockets from being routed back into Android VpnService.
type SocketProtector interface {
	Protect(fd int) bool
}

// LogWriter receives log messages from olcRTC.
type LogWriter interface {
	WriteLog(msg string)
}

type protectorAdapter struct{ p SocketProtector }

func (a protectorAdapter) Protect(fd int) bool { return a.p.Protect(fd) }

type logWriterAdapter struct{ w LogWriter }

func (a logWriterAdapter) WriteLog(msg string) { a.w.WriteLog(msg) }

func (b *logWriterAdapter) Write(p []byte) (int, error) {
	if b == nil || b.w == nil {
		return len(p), nil
	}
	b.w.WriteLog(string(p))
	return len(p), nil
}

var (
	errAlreadyRunning     = errors.New("olcRTC already running")
	errCarrierRequired    = errors.New("carrier is required")
	errRoomIDRequired     = errors.New("roomID is required")
	errClientIDRequired   = errors.New("clientID is required")
	errKeyHexRequired     = errors.New("keyHex is required")
	errNotRunning         = errors.New("olcRTC is not running")
	errStoppedBeforeReady = errors.New("olcRTC stopped before becoming ready")
	errStartTimedOut      = errors.New("olcRTC start timed out")
)

const (
	defaultLink      = "direct"
	transportData    = "datachannel"
	transportVP8     = "vp8channel"
	transportSEI     = "seichannel"
	transportVideo   = "videochannel"
	defaultDNSServer = "1.1.1.1:53"
	carrierWBStream  = "wbstream"
	carrierJazz      = "jazz"
	roomURLAny       = "any"
)

type mobileConfig struct {
	link      string
	transport string
	dnsServer string
	engine    string
	url       string
	token     string

	vp8FPS       int
	vp8BatchSize int

	seiFPS          int
	seiBatchSize    int
	seiFragmentSize int
	seiAckTimeoutMS int

	videoWidth      int
	videoHeight     int
	videoFPS        int
	videoBitrate    string
	videoHW         string
	videoQRSize     int
	videoQRRecovery string
	videoCodec      string
	videoTileModule int
	videoTileRS     int

	livenessIntervalMS int
	livenessTimeoutMS  int
	livenessFailures   int

	trafficMaxPayload int
	trafficMinDelayMS int
	trafficMaxDelayMS int
}

var (
	runtimeMu          sync.Mutex
	defaults           mobileConfig
	defaultsSet        sync.Once
	registerSet        sync.Once
	runClientWithReady = client.RunWithReady
	cancel             context.CancelFunc
	done               chan struct{}
	ready              chan struct{}
	errRun             error

	dnsMu     sync.RWMutex
	olcDNS    = defaultDNSServer
	hijackDNS = "77.88.8.8:53"

	autoDNSMu       sync.Mutex
	autoDNSConn     *net.UDPConn
	autoDNSUpMu     sync.RWMutex
	autoDNSUpstream string
)

func normalizeDNSAddress(dnsServer string) string {
	dnsServer = strings.TrimSpace(dnsServer)
	if dnsServer == "" {
		return "1.1.1.1:53"
	}
	if strings.HasPrefix(dnsServer, "[") && strings.Contains(dnsServer, "]:") {
		return dnsServer
	}
	if strings.Count(dnsServer, ":") == 0 {
		return dnsServer + ":53"
	}
	if strings.Count(dnsServer, ":") > 1 && !strings.HasPrefix(dnsServer, "[") {
		return "[" + dnsServer + "]:53"
	}
	return dnsServer
}

func SetProtector(p SocketProtector) {
	if p == nil {
		protect.Protector = nil
		return
	}
	adapter := protectorAdapter{p: p}
	protect.Protector = func(fd int) bool { return adapter.Protect(fd) }
}

func protectedDialer(timeout time.Duration) *net.Dialer {
	return &net.Dialer{
		Timeout: timeout,
		Control: func(network, address string, c syscall.RawConn) error {
			if protect.Protector == nil {
				return nil
			}
			var protectErr error
			err := c.Control(func(fd uintptr) {
				if !protect.Protector(int(fd)) {
					protectErr = fmt.Errorf("VpnService.protect failed for fd=%d %s %s", fd, network, address)
				}
			})
			if err != nil {
				return err
			}
			return protectErr
		},
	}
}

func SetLogWriter(w LogWriter) {
	if w != nil {
		log.SetOutput(&logWriterAdapter{w: w})
	}
}

func SetProviders() { registerDefaults() }

func SetTransport(transport string) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.transport = normalizeTransport(transport)
}

func SetLink(link string) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.link = normalizeLink(link)
}

// SetDNS controls DNS used by olcRTC before the VPN tunnel is fully up.
// On Android, Go can otherwise try broken localhost DNS like [::1]:53.
func SetDNS(dnsServer string) {
	dnsServer = normalizeDNSAddress(dnsServer)
	setDefaultDNSServer(dnsServer)
	dnsMu.Lock()
	olcDNS = dnsServer
	dnsMu.Unlock()
	ForceDNS(dnsServer)
}

func setDefaultDNSServer(dnsServer string) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.dnsServer = dnsServer
}

// SetHijackDNS controls where UDP DNS packets from Android apps are resolved.
// They are converted to DNS-over-TCP and sent through the olcRTC SOCKS proxy.
func SetHijackDNS(dnsServer string) {
	dnsMu.Lock()
	hijackDNS = normalizeDNSAddress(dnsServer)
	dnsMu.Unlock()
}

func currentOlcDNS() string {
	dnsMu.RLock()
	defer dnsMu.RUnlock()
	return olcDNS
}

func currentHijackDNS() string {
	dnsMu.RLock()
	defer dnsMu.RUnlock()
	return hijackDNS
}

// ForceDNS replaces Go's default resolver. This is only for olcRTC's own
// pre-tunnel HTTP/WebRTC setup, not for app traffic inside the TUN.
func ForceDNS(dnsServer string) {
	dnsServer = normalizeDNSAddress(dnsServer)
	net.DefaultResolver = &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			d := protectedDialer(5 * time.Second)
			return d.DialContext(ctx, "udp", dnsServer)
		},
	}
}

// SetAutoDNS starts a tiny local DNS relay used only by olcRTC before the VPN is up.
// The relay tries DNS candidates in order: system/operator UDP, public UDP, then DoH
// with bootstrap IPs. It returns the local resolver address used by Go, for logging.
func SetAutoDNS(candidatesCSV string, probeHost string) string {
	upstreams := parseDNSCandidates(candidatesCSV)
	if len(upstreams) == 0 {
		upstreams = defaultDNSCandidates()
	}
	setAutoDNSUpstream("")

	addr, err := startAutoDNSRelay(upstreams)
	if err != nil {
		fallback := firstUDPAddress(upstreams)
		if fallback == "" {
			fallback = "1.1.1.1:53"
		}
		setAutoDNSUpstream("fallback-direct:" + fallback)
		SetDNS(fallback)
		return fallback
	}

	setDefaultDNSServer(addr)
	dnsMu.Lock()
	olcDNS = addr
	dnsMu.Unlock()
	ForceDNS(addr)

	probeHost = strings.TrimSpace(probeHost)
	if probeHost != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		defer cancel()
		_, _ = net.DefaultResolver.LookupHost(ctx, probeHost)
	}

	return addr
}

func GetAutoDNSUpstream() string {
	autoDNSUpMu.RLock()
	defer autoDNSUpMu.RUnlock()
	return autoDNSUpstream
}

func setAutoDNSUpstream(value string) {
	autoDNSUpMu.Lock()
	autoDNSUpstream = value
	autoDNSUpMu.Unlock()
}

type dnsUpstream struct {
	kind      string
	addr      string
	endpoint  string
	bootstrap string
}

func defaultDNSCandidates() []dnsUpstream {
	return []dnsUpstream{
		{kind: "udp", addr: "77.88.8.8:53"},
		{kind: "udp", addr: "77.88.8.1:53"},
		{kind: "udp", addr: "1.1.1.1:53"},
		{kind: "udp", addr: "8.8.8.8:53"},
		{kind: "doh", endpoint: "https://common.dot.dns.yandex.net/dns-query", bootstrap: "77.88.8.8:443"},
		{kind: "doh", endpoint: "https://cloudflare-dns.com/dns-query", bootstrap: "1.1.1.1:443"},
		{kind: "doh", endpoint: "https://dns.google/dns-query", bootstrap: "8.8.8.8:443"},
	}
}

func parseDNSCandidates(csv string) []dnsUpstream {
	var out []dnsUpstream
	seen := map[string]bool{}
	add := func(u dnsUpstream) {
		key := u.kind + "|" + u.addr + "|" + u.endpoint + "|" + u.bootstrap
		if seen[key] {
			return
		}
		seen[key] = true
		out = append(out, u)
	}

	for _, raw := range strings.Split(csv, ",") {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			continue
		}
		if strings.HasPrefix(raw, "doh:") {
			spec := strings.TrimPrefix(raw, "doh:")
			bootstrap := ""
			if idx := strings.LastIndex(spec, "@"); idx > 0 {
				bootstrap = spec[idx+1:]
				spec = spec[:idx]
			}
			if bootstrap != "" && !strings.Contains(bootstrap, ":") {
				bootstrap += ":443"
			}
			add(dnsUpstream{kind: "doh", endpoint: spec, bootstrap: bootstrap})
			continue
		}
		if strings.HasPrefix(raw, "udp:") {
			raw = strings.TrimPrefix(raw, "udp:")
		}
		add(dnsUpstream{kind: "udp", addr: normalizeDNSAddress(raw)})
	}

	for _, u := range defaultDNSCandidates() {
		add(u)
	}
	return out
}

func firstUDPAddress(upstreams []dnsUpstream) string {
	for _, u := range upstreams {
		if u.kind == "udp" && u.addr != "" {
			return u.addr
		}
	}
	return ""
}

func describeDNSUpstream(u dnsUpstream) string {
	switch u.kind {
	case "udp":
		return "udp:" + normalizeDNSAddress(u.addr)
	case "doh":
		if u.bootstrap != "" {
			return "doh:" + u.endpoint + "@" + u.bootstrap
		}
		return "doh:" + u.endpoint
	default:
		return u.kind
	}
}

func startAutoDNSRelay(upstreams []dnsUpstream) (string, error) {
	autoDNSMu.Lock()
	defer autoDNSMu.Unlock()

	if autoDNSConn != nil {
		_ = autoDNSConn.Close()
		autoDNSConn = nil
	}

	conn, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0})
	if err != nil {
		return "", err
	}
	autoDNSConn = conn
	addr := conn.LocalAddr().String()

	ups := append([]dnsUpstream(nil), upstreams...)
	go autoDNSLoop(conn, ups)
	return addr, nil
}

func autoDNSLoop(conn *net.UDPConn, upstreams []dnsUpstream) {
	buf := make([]byte, 4096)
	for {
		n, addr, err := conn.ReadFromUDP(buf)
		if err != nil {
			return
		}
		query := append([]byte(nil), buf[:n]...)
		go func() {
			resp, err := autoDNSQuery(query, upstreams)
			if err != nil || len(resp) == 0 {
				return
			}
			_, _ = conn.WriteToUDP(resp, addr)
		}()
	}
}

func autoDNSQuery(query []byte, upstreams []dnsUpstream) ([]byte, error) {
	var lastErr error
	for _, up := range upstreams {
		var resp []byte
		var err error
		switch up.kind {
		case "udp":
			resp, err = dnsQueryUDP(query, up.addr)
		case "doh":
			resp, err = dnsQueryDoH(query, up.endpoint, up.bootstrap)
		default:
			continue
		}
		if err == nil && len(resp) > 0 {
			setAutoDNSUpstream(describeDNSUpstream(up))
			return resp, nil
		}
		lastErr = err
	}
	if lastErr == nil {
		lastErr = errors.New("no dns upstreams")
	}
	return nil, lastErr
}

func dnsQueryUDP(query []byte, server string) ([]byte, error) {
	server = normalizeDNSAddress(server)
	conn, err := net.DialTimeout("udp", server, 1200*time.Millisecond)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(1200 * time.Millisecond))
	if _, err := conn.Write(query); err != nil {
		return nil, err
	}
	buf := make([]byte, 4096)
	n, err := conn.Read(buf)
	if err != nil {
		return nil, err
	}
	return append([]byte(nil), buf[:n]...), nil
}

func dnsQueryDoH(query []byte, endpoint string, bootstrap string) ([]byte, error) {
	endpoint = strings.TrimSpace(endpoint)
	if endpoint == "" {
		return nil, errors.New("empty doh endpoint")
	}
	u, err := url.Parse(endpoint)
	if err != nil {
		return nil, err
	}
	host := u.Hostname()
	if host == "" {
		return nil, fmt.Errorf("bad doh endpoint host: %q", endpoint)
	}
	if bootstrap != "" && !strings.Contains(bootstrap, ":") {
		bootstrap += ":443"
	}

	dialer := protectedDialer(2500 * time.Millisecond)
	transport := &http.Transport{
		TLSClientConfig: &tls.Config{ServerName: host},
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			if bootstrap != "" {
				return dialer.DialContext(ctx, network, bootstrap)
			}
			return dialer.DialContext(ctx, network, address)
		},
	}
	client := &http.Client{Transport: transport, Timeout: 3500 * time.Millisecond}

	req, err := http.NewRequest("POST", endpoint, bytes.NewReader(query))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/dns-message")
	req.Header.Set("Accept", "application/dns-message")
	req.Host = u.Host

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("doh status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 65536))
	if err != nil {
		return nil, err
	}
	if len(body) == 0 {
		return nil, errors.New("empty doh response")
	}
	return body, nil
}

func SetVP8Options(fps, batchSize int) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.vp8FPS = clampAtLeastOne(fps, 120)
	defaults.vp8BatchSize = clampAtLeastOne(batchSize, 256)
}

func SetSEIOptions(fps, batchSize, fragmentSize, ackTimeoutMS int) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.seiFPS = clampAtLeastOne(fps, 240)
	defaults.seiBatchSize = clampAtLeastOne(batchSize, 512)
	defaults.seiFragmentSize = clampAtLeastOne(fragmentSize, 4096)
	defaults.seiAckTimeoutMS = clampAtLeastOne(ackTimeoutMS, 30000)
}

func SetVideoOptions(codec string, width, height, fps int, bitrate string, hw string, qrRecovery string, qrSize int, tileModule int, tileRS int) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()

	codec = strings.TrimSpace(strings.ToLower(codec))
	if codec == "" {
		codec = "qrcode"
	}
	if codec != "qrcode" && codec != "tile" {
		codec = "qrcode"
	}

	bitrate = strings.TrimSpace(bitrate)
	if bitrate == "" {
		bitrate = "5000k"
	}

	hw = strings.TrimSpace(strings.ToLower(hw))
	if hw == "" || hw == "android" || hw == "auto" {
		hw = "none"
	}

	qrRecovery = strings.TrimSpace(strings.ToLower(qrRecovery))
	switch qrRecovery {
	case "low", "medium", "high", "highest":
	default:
		qrRecovery = "low"
	}

	defaults.videoCodec = codec
	defaults.videoWidth = clampAtLeastOne(width, 4096)
	defaults.videoHeight = clampAtLeastOne(height, 4096)
	defaults.videoFPS = clampAtLeastOne(fps, 240)
	defaults.videoBitrate = bitrate
	defaults.videoHW = hw
	defaults.videoQRRecovery = qrRecovery
	defaults.videoQRSize = clampNonNegative(qrSize, 65535)
	defaults.videoTileModule = clampAtLeastOne(tileModule, 270)
	defaults.videoTileRS = clampNonNegative(tileRS, 200)
}

// SetFFmpegPath is retained for ABI compatibility with the Android reflection
// bridge (OlcMobileBridge.setFFmpegPathIfAvailable). Upstream videochannel now
// uses a pure-Go codec (no external ffmpeg binary), so this is a no-op.
func SetFFmpegPath(path string) error {
	_ = path
	return nil
}

func SetLivenessOptions(intervalMS, timeoutMS, failures int) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.livenessIntervalMS = clampNonNegative(intervalMS, 300000)
	defaults.livenessTimeoutMS = clampNonNegative(timeoutMS, 300000)
	defaults.livenessFailures = clampNonNegative(failures, 100)
}

func SetTrafficOptions(maxPayload, minDelayMS, maxDelayMS int) {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	ensureDefaultConfigLocked()
	defaults.trafficMaxPayload = clampNonNegative(maxPayload, 65535)
	defaults.trafficMinDelayMS = clampNonNegative(minDelayMS, 60000)
	defaults.trafficMaxDelayMS = clampNonNegative(maxDelayMS, 60000)
}

// SetMultipathOptions is retained for ABI compatibility with the Android
// reflection bridge (OlcMobileBridge.setMultipathOptionsIfAvailable). The
// upstream olcRTC core has no multipath/lane support — sessions are always
// single-lane — so this is intentionally a no-op. The bridge only calls it for
// the legacy "mtslink" carrier, which upstream does not ship.
func SetMultipathOptions(lanes, controlLanes, connectParallelism, minReady, maxStreamsPerLane int) {
	_ = lanes
	_ = controlLanes
	_ = connectParallelism
	_ = minReady
	_ = maxStreamsPerLane
}

func SetDebug(enabled bool) {
	logger.SetVerbose(enabled)
	if enabled {
		log.SetFlags(log.Ltime | log.Lshortfile)
		return
	}
	log.SetFlags(log.Ltime)
}

func Start(carrierName, roomID, clientID, keyHex string, socksPort int, socksUser, socksPass string) error {
	runtimeMu.Lock()
	ensureDefaultConfigLocked()
	cfg := defaults
	runtimeMu.Unlock()
	return startWithConfig(carrierName, cfg.transport, roomID, clientID, keyHex, socksPort, socksUser, socksPass, cfg)
}

func StartWithTransport(carrierName, transportName, roomID, clientID, keyHex string, socksPort int, socksUser, socksPass string) error {
	runtimeMu.Lock()
	ensureDefaultConfigLocked()
	cfg := defaults
	cfg.transport = transportName
	runtimeMu.Unlock()
	return startWithConfig(carrierName, transportName, roomID, clientID, keyHex, socksPort, socksUser, socksPass, cfg)
}

func mobileClientConfig(
	cfg mobileConfig,
	carrierName string,
	roomURL string,
	keyHex string,
	clientID string,
	socksPort int,
	socksUser string,
	socksPass string,
) client.Config {
	return client.Config{
		Transport:        cfg.transport,
		Carrier:          carrierName,
		RoomURL:          roomURL,
		ChannelID:        clientID,
		KeyHex:           keyHex,
		DeviceID:         clientID,
		LocalAddr:        fmt.Sprintf("127.0.0.1:%d", socksPort),
		DNSServer:        cfg.dnsServer,
		SOCKSUser:        socksUser,
		SOCKSPass:        socksPass,
		TransportOptions: mobileTransportOptions(cfg),
		Engine:           cfg.engine,
		URL:              cfg.url,
		Token:            cfg.token,
		Liveness:         mobileLivenessConfig(cfg),
		Traffic:          mobileTrafficConfig(cfg),
	}
}

func mobileLivenessConfig(cfg mobileConfig) control.Config {
	return control.Config{
		Interval: time.Duration(cfg.livenessIntervalMS) * time.Millisecond,
		Timeout:  time.Duration(cfg.livenessTimeoutMS) * time.Millisecond,
		Failures: cfg.livenessFailures,
	}
}

func mobileTrafficConfig(cfg mobileConfig) transport.TrafficConfig {
	return transport.TrafficConfig{
		MaxPayloadSize: cfg.trafficMaxPayload,
		MinDelay:       time.Duration(cfg.trafficMinDelayMS) * time.Millisecond,
		MaxDelay:       time.Duration(cfg.trafficMaxDelayMS) * time.Millisecond,
	}
}

func mobileTransportOptions(cfg mobileConfig) transport.Options {
	switch cfg.transport {
	case transportVP8:
		return vp8channel.Options{
			FPS:       cfg.vp8FPS,
			BatchSize: cfg.vp8BatchSize,
		}
	case transportSEI:
		return seichannel.Options{
			FPS:          cfg.seiFPS,
			BatchSize:    cfg.seiBatchSize,
			FragmentSize: cfg.seiFragmentSize,
			AckTimeoutMS: cfg.seiAckTimeoutMS,
		}
	case transportVideo:
		return videochannel.Options{
			Width:      cfg.videoWidth,
			Height:     cfg.videoHeight,
			FPS:        cfg.videoFPS,
			Bitrate:    cfg.videoBitrate,
			HW:         cfg.videoHW,
			QRSize:     cfg.videoQRSize,
			QRRecovery: cfg.videoQRRecovery,
			Codec:      cfg.videoCodec,
			TileModule: cfg.videoTileModule,
			TileRS:     cfg.videoTileRS,
		}
	default:
		return nil
	}
}

func startWithConfig(carrierName, transportName, roomID, clientID, keyHex string, socksPort int, socksUser, socksPass string, cfg mobileConfig) error {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()

	registerDefaults()
	carrierName = normalizeCarrier(carrierName)
	if transportName != "" {
		cfg.transport = normalizeTransport(transportName)
	} else {
		cfg.transport = normalizeTransport(cfg.transport)
	}
	cfg = applyCarrierRuntimeDefaults(carrierName, cfg)
	if cancel != nil {
		return errAlreadyRunning
	}
	if err := validateStartArgs(carrierName, roomID, clientID, keyHex); err != nil {
		return err
	}
	if socksPort <= 0 {
		socksPort = 10808
	}

	roomURL := buildRoomURL(carrierName, roomID)
	authDefaults, err := session.ApplyAuthDefaults(session.Config{Auth: carrierName, Engine: cfg.engine, URL: cfg.url, Token: cfg.token})
	if err != nil {
		return fmt.Errorf("apply auth defaults: %w", err)
	}
	cfg.engine = authDefaults.Engine
	cfg.url = authDefaults.URL
	cfg.token = authDefaults.Token

	ctx, cancelFunc := context.WithCancel(context.Background())
	cancel = cancelFunc
	done = make(chan struct{})
	ready = make(chan struct{})
	localReady := ready
	errRun = nil

	var readyOnce sync.Once
	ForceDNS(currentOlcDNS())
	go func() {
		defer cancelFunc()
		err := runClientWithReady(
			ctx,
			mobileClientConfig(cfg, carrierName, roomURL, keyHex, clientID, socksPort, socksUser, socksPass),
			func() { readyOnce.Do(func() { close(localReady) }) },
		)
		runtimeMu.Lock()
		cancel = nil
		errRun = err
		runtimeMu.Unlock()
		close(done)
	}()
	return nil
}

func Check(carrierName, transportName, roomID, clientID, keyHex string, socksPort int, timeoutMillis int, vp8FPS int, vp8BatchSize int) (int64, error) {
	registerDefaults()
	carrierName = normalizeCarrier(carrierName)
	transportName = normalizeTransport(transportName)
	if err := validateStartArgs(carrierName, roomID, clientID, keyHex); err != nil {
		return 0, err
	}
	if timeoutMillis <= 0 {
		timeoutMillis = 8000
	}
	if socksPort <= 0 {
		socksPort = 10808
	}

	ctx, cancelFunc := context.WithCancel(context.Background())
	defer cancelFunc()
	readyCh := make(chan struct{})
	doneCh := make(chan error, 1)
	var readyOnce sync.Once
	startedAt := time.Now()
	cfg := defaultMobileConfig()
	cfg.transport = transportName
	cfg.vp8FPS = clampAtLeastOne(vp8FPS, 120)
	cfg.vp8BatchSize = clampAtLeastOne(vp8BatchSize, 256)
	if authDefaults, err := session.ApplyAuthDefaults(session.Config{Auth: carrierName}); err == nil {
		cfg.engine = authDefaults.Engine
		cfg.url = authDefaults.URL
		cfg.token = authDefaults.Token
	}
	ForceDNS(currentOlcDNS())
	go func() {
		doneCh <- runClientWithReady(
			ctx,
			mobileClientConfig(cfg, carrierName, buildRoomURL(carrierName, roomID), keyHex, clientID, socksPort, "", ""),
			func() { readyOnce.Do(func() { close(readyCh) }) },
		)
	}()

	timer := time.NewTimer(time.Duration(timeoutMillis) * time.Millisecond)
	defer timer.Stop()
	select {
	case <-readyCh:
		elapsed := time.Since(startedAt).Milliseconds()
		cancelFunc()
		waitForCheckDone(doneCh)
		return elapsed, nil
	case err := <-doneCh:
		if err != nil {
			return 0, err
		}
		return 0, errStoppedBeforeReady
	case <-timer.C:
		cancelFunc()
		waitForCheckDone(doneCh)
		return 0, errStartTimedOut
	}
}

func WaitReady(timeoutMillis int) error {
	runtimeMu.Lock()
	r := ready
	d := done
	runErr := errRun
	running := cancel != nil
	runtimeMu.Unlock()

	if r == nil {
		if runErr != nil {
			return runErr
		}
		return errNotRunning
	}
	select {
	case <-r:
		return nil
	default:
	}
	if !running {
		if runErr != nil {
			return runErr
		}
		return errStoppedBeforeReady
	}

	timer := time.NewTimer(time.Duration(timeoutMillis) * time.Millisecond)
	defer timer.Stop()
	select {
	case <-r:
		return nil
	case <-d:
		runtimeMu.Lock()
		runErr = errRun
		runtimeMu.Unlock()
		if runErr != nil {
			return runErr
		}
		return errStoppedBeforeReady
	case <-timer.C:
		return errStartTimedOut
	}
}

func Stop() {
	runtimeMu.Lock()
	cancelFunc := cancel
	doneCh := done
	runtimeMu.Unlock()
	if cancelFunc == nil {
		return
	}
	cancelFunc()
	if doneCh != nil {
		<-doneCh
	}
}

func IsRunning() bool {
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	return cancel != nil
}

func registerDefaults() { registerSet.Do(session.RegisterDefaults) }

func waitForCheckDone(doneCh <-chan error) {
	select {
	case <-doneCh:
	case <-time.After(2 * time.Second):
	}
}

func ensureDefaultConfigLocked() {
	defaultsSet.Do(func() { defaults = defaultMobileConfig() })
}

func defaultMobileConfig() mobileConfig {
	return mobileConfig{
		link:            defaultLink,
		transport:       transportData,
		dnsServer:       defaultDNSServer,
		vp8FPS:          25,
		vp8BatchSize:    1,
		seiFPS:          20,
		seiBatchSize:    1,
		seiFragmentSize: 900,
		seiAckTimeoutMS: 3000,
		videoWidth:      1920,
		videoHeight:     1080,
		videoFPS:        30,
		videoBitrate:    "2M",
		videoHW:         "none",
		videoQRSize:     0,
		videoQRRecovery: "low",
		videoCodec:      "qrcode",
		videoTileModule: 4,
		videoTileRS:     20,
	}
}

func applyCarrierRuntimeDefaults(carrierName string, cfg mobileConfig) mobileConfig {
	if carrierName == "mtslink" {
		if cfg.livenessIntervalMS <= 0 {
			cfg.livenessIntervalMS = 20000
		}
		if cfg.livenessTimeoutMS <= 0 {
			cfg.livenessTimeoutMS = 60000
		}
		if cfg.livenessFailures <= 0 {
			cfg.livenessFailures = 3
		}
		payloadFloor := cfg.seiFragmentSize * 8
		if payloadFloor < 1600 {
			payloadFloor = 1600
		}
		if cfg.trafficMaxPayload <= 0 {
			cfg.trafficMaxPayload = payloadFloor
		} else if cfg.trafficMaxPayload < payloadFloor {
			cfg.trafficMaxPayload = payloadFloor
		}
		if cfg.trafficMinDelayMS <= 0 {
			cfg.trafficMinDelayMS = 4
		}
		if cfg.trafficMaxDelayMS <= 0 {
			cfg.trafficMaxDelayMS = 18
		}
	}
	return cfg
}

func normalizeLink(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "", defaultLink:
		return defaultLink
	default:
		logger.Warnf("unknown link mode %q, falling back to direct", value)
		return defaultLink
	}
}

func normalizeTransport(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case transportData, "data", "dc", "data_channel", "data-channel", "":
		return transportData
	case transportVP8, "vp8", "vp8_channel", "vp8-channel":
		return transportVP8
	case transportSEI, "sei", "sei_channel", "sei-channel":
		return transportSEI
	case transportVideo, "video", "vid", "video_channel", "video-channel":
		return transportVideo
	default:
		logger.Warnf("unknown transport %q, falling back to datachannel", value)
		return transportData
	}
}

func normalizeCarrier(carrierName string) string {
	carrierName = strings.TrimSpace(carrierName)
	if carrierName == carrierWBStream {
		return carrierWBStream
	}
	return carrierName
}

func validateStartArgs(carrierName, roomID, clientID, keyHex string) error {
	switch {
	case carrierName == "":
		return errCarrierRequired
	case roomID == "" && carrierName != carrierJazz:
		return errRoomIDRequired
	case clientID == "":
		return errClientIDRequired
	case keyHex == "":
		return errKeyHexRequired
	default:
		return nil
	}
}

func buildRoomURL(carrierName, roomID string) string {
	switch carrierName {
	case "telemost":
		return roomID
	case carrierJazz:
		if roomID == "" {
			return roomURLAny
		}
		return roomID
	case carrierWBStream:
		return roomID
	default:
		return roomID
	}
}

func clampAtLeastOne(value, maxValue int) int {
	if value < 1 {
		return 1
	}
	if maxValue > 0 && value > maxValue {
		return maxValue
	}
	return value
}

func clampNonNegative(value, maxValue int) int {
	if value < 0 {
		return 0
	}
	if maxValue > 0 && value > maxValue {
		return maxValue
	}
	return value
}

var (
	tunMu      sync.Mutex
	tunRunning bool
)

// StartTun2Socks starts tun2socks inside the Android app process.
func StartTun2Socks(fd int, proxyURL string, mtu int, logLevel string) error {
	return StartTun2SocksWithDNSAndLimit(fd, proxyURL, mtu, logLevel, currentHijackDNS(), 6)
}

// StartTun2SocksWithDNS starts tun2socks with the default TCP dial limiter.
func StartTun2SocksWithDNS(fd int, proxyURL string, mtu int, logLevel string, dnsUpstream string) error {
	return StartTun2SocksWithDNSAndLimit(fd, proxyURL, mtu, logLevel, dnsUpstream, 6)
}

// StartTun2SocksWithDNSAndLimit starts tun2socks and wraps its proxy so UDP DNS :53 is
// answered locally by the Android app through direct Wi-Fi/LTE DNS. DNS must not
// create olcRTC SOCKS/media streams; video transports cannot survive per-query DNS load.
// tcpDialLimit intentionally throttles Android/browser startup bursts; vp8channel should
// usually use a smaller value than datachannel.
func StartTun2SocksWithDNSAndLimit(fd int, proxyURL string, mtu int, logLevel string, dnsUpstream string, tcpDialLimit int) error {
	tunMu.Lock()
	defer tunMu.Unlock()

	if fd < 0 {
		return fmt.Errorf("invalid tun fd: %d", fd)
	}
	if strings.TrimSpace(proxyURL) == "" {
		proxyURL = "socks5://127.0.0.1:10808"
	}
	if !strings.Contains(proxyURL, "://") {
		proxyURL = "socks5://" + proxyURL
	}
	if mtu <= 0 {
		mtu = 1500
	}
	if strings.TrimSpace(logLevel) == "" {
		logLevel = "info"
	}
	tcpDialLimit = clampAtLeastOne(tcpDialLimit, 32)
	dnsUpstream = normalizeDNSAddress(dnsUpstream)
	SetHijackDNS(dnsUpstream)

	if tunRunning {
		engine.Stop()
		tunRunning = false
	}

	engine.Insert(&engine.Key{
		MTU:        mtu,
		Device:     fmt.Sprintf("fd://%d", fd),
		Proxy:      proxyURL,
		LogLevel:   logLevel,
		UDPTimeout: 30 * time.Second,
	})
	engine.Start()

	base := tunnel.T().Proxy()
	tunnel.T().SetProxy(&dnsTCPProxy{base: base, upstream: dnsUpstream, tcpTokens: make(chan struct{}, tcpDialLimit)})

	tunRunning = true
	return nil
}

func StopTun2Socks() {
	tunMu.Lock()
	defer tunMu.Unlock()
	if tunRunning {
		engine.Stop()
		tunRunning = false
	}
}

type dnsTCPProxy struct {
	base      proxy.Proxy
	upstream  string
	tcpTokens chan struct{}
}

func (p *dnsTCPProxy) DialContext(ctx context.Context, metadata *M.Metadata) (net.Conn, error) {
	if metadata != nil {
		// Block Android Private DNS / DNS-over-TLS inside the tunnel.
		// If TCP/853 is allowed to hang, Android can keep retrying DoT and make browsing look broken.
		if metadata.DstPort == 853 {
			return nil, fmt.Errorf("blocked tcp/853 private dns")
		}
	}

	// Android build uses datachannel/vp8channel. Keep a small TCP dial limiter
	// so browser bursts do not overload slow carriers during startup.
	if p.tcpTokens != nil {
		select {
		case p.tcpTokens <- struct{}{}:
			defer func() { <-p.tcpTokens }()
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	return p.base.DialContext(ctx, metadata)
}

func (p *dnsTCPProxy) DialUDP(metadata *M.Metadata) (net.PacketConn, error) {
	if metadata != nil {
		if metadata.DstPort == 53 {
			return newDNSOverTCPPacketConn(p.base, p.upstream), nil
		}
		if metadata.DstPort == 443 {
			return newUDPBlackholePacketConn(), nil
		}
	}
	return p.base.DialUDP(metadata)
}

type udpBlackholePacketConn struct {
	done       chan struct{}
	once       sync.Once
	deadlineMu sync.Mutex
	deadline   time.Time
}

func newUDPBlackholePacketConn() *udpBlackholePacketConn {
	return &udpBlackholePacketConn{done: make(chan struct{})}
}

func (pc *udpBlackholePacketConn) ReadFrom(p []byte) (int, net.Addr, error) {
	pc.deadlineMu.Lock()
	deadline := pc.deadline
	pc.deadlineMu.Unlock()

	var timer <-chan time.Time
	if !deadline.IsZero() {
		d := time.Until(deadline)
		if d <= 0 {
			return 0, nil, dnsTimeoutError{}
		}
		timer = time.After(d)
	}

	select {
	case <-pc.done:
		return 0, nil, errors.New("udp blackhole closed")
	case <-timer:
		return 0, nil, dnsTimeoutError{}
	}
}

func (pc *udpBlackholePacketConn) WriteTo(b []byte, addr net.Addr) (int, error) { return len(b), nil }
func (pc *udpBlackholePacketConn) Close() error                                 { pc.once.Do(func() { close(pc.done) }); return nil }
func (pc *udpBlackholePacketConn) LocalAddr() net.Addr {
	return &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0}
}
func (pc *udpBlackholePacketConn) SetDeadline(t time.Time) error { pc.SetReadDeadline(t); return nil }
func (pc *udpBlackholePacketConn) SetReadDeadline(t time.Time) error {
	pc.deadlineMu.Lock()
	pc.deadline = t
	pc.deadlineMu.Unlock()
	return nil
}
func (pc *udpBlackholePacketConn) SetWriteDeadline(time.Time) error { return nil }

type dnsPacket struct {
	data []byte
	addr net.Addr
}

type dnsTimeoutError struct{}

func (dnsTimeoutError) Error() string   { return "i/o timeout" }
func (dnsTimeoutError) Timeout() bool   { return true }
func (dnsTimeoutError) Temporary() bool { return true }

type dnsOverTCPPacketConn struct {
	base     proxy.Proxy
	upstream string

	respCh chan dnsPacket
	done   chan struct{}
	once   sync.Once

	deadlineMu   sync.Mutex
	readDeadline time.Time
}

func newDNSOverTCPPacketConn(base proxy.Proxy, upstream string) *dnsOverTCPPacketConn {
	return &dnsOverTCPPacketConn{
		base:     base,
		upstream: normalizeDNSAddress(upstream),
		respCh:   make(chan dnsPacket, 32),
		done:     make(chan struct{}),
	}
}

func (pc *dnsOverTCPPacketConn) ReadFrom(p []byte) (int, net.Addr, error) {
	pc.deadlineMu.Lock()
	deadline := pc.readDeadline
	pc.deadlineMu.Unlock()

	var timer <-chan time.Time
	if !deadline.IsZero() {
		d := time.Until(deadline)
		if d <= 0 {
			return 0, nil, dnsTimeoutError{}
		}
		timer = time.After(d)
	}

	select {
	case pkt := <-pc.respCh:
		n := copy(p, pkt.data)
		return n, pkt.addr, nil
	case <-pc.done:
		return 0, nil, errors.New("dns packet conn closed")
	case <-timer:
		return 0, nil, dnsTimeoutError{}
	}
}

func (pc *dnsOverTCPPacketConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	select {
	case <-pc.done:
		return 0, errors.New("dns packet conn closed")
	default:
	}

	query := append([]byte(nil), b...)
	go func() {
		response, err := pc.queryOverTCP(query)
		if err != nil {
			return
		}
		select {
		case pc.respCh <- dnsPacket{data: response, addr: addr}:
		case <-pc.done:
		}
	}()

	return len(b), nil
}

func (pc *dnsOverTCPPacketConn) queryOverTCP(query []byte) ([]byte, error) {
	// Despite the historical name, this resolver is intentionally direct from the
	// Android app process, not through pc.base/olcRTC SOCKS. The app package is
	// excluded from VpnService, so DNS packets leave through the active Wi-Fi/LTE
	// network and do not create one media-stream per DNS request.
	if resp, err := pc.queryDirectUDP(query); err == nil && len(resp) > 0 {
		return resp, nil
	}
	return pc.queryDirectTCP(query)
}

func (pc *dnsOverTCPPacketConn) queryDirectUDP(query []byte) ([]byte, error) {
	upstream := normalizeDNSAddress(pc.upstream)
	d := protectedDialer(1800 * time.Millisecond)
	conn, err := d.DialContext(context.Background(), "udp", upstream)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(2200 * time.Millisecond))
	if _, err = conn.Write(query); err != nil {
		return nil, err
	}
	buf := make([]byte, 4096)
	n, err := conn.Read(buf)
	if err != nil {
		return nil, err
	}
	return append([]byte(nil), buf[:n]...), nil
}

func (pc *dnsOverTCPPacketConn) queryDirectTCP(query []byte) ([]byte, error) {
	upstream := normalizeDNSAddress(pc.upstream)
	d := protectedDialer(2500 * time.Millisecond)
	conn, err := d.DialContext(context.Background(), "tcp", upstream)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(4 * time.Second))

	if len(query) > 65535 {
		return nil, fmt.Errorf("dns query too large: %d", len(query))
	}

	var hdr [2]byte
	binary.BigEndian.PutUint16(hdr[:], uint16(len(query)))
	if _, err = conn.Write(hdr[:]); err != nil {
		return nil, err
	}
	if _, err = conn.Write(query); err != nil {
		return nil, err
	}

	if _, err = io.ReadFull(conn, hdr[:]); err != nil {
		return nil, err
	}
	n := int(binary.BigEndian.Uint16(hdr[:]))
	if n <= 0 || n > 65535 {
		return nil, fmt.Errorf("bad dns tcp response size: %d", n)
	}
	resp := make([]byte, n)
	if _, err = io.ReadFull(conn, resp); err != nil {
		return nil, err
	}
	return resp, nil
}

func (pc *dnsOverTCPPacketConn) Close() error {
	pc.once.Do(func() { close(pc.done) })
	return nil
}

func (pc *dnsOverTCPPacketConn) LocalAddr() net.Addr {
	return &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0}
}

func (pc *dnsOverTCPPacketConn) SetDeadline(t time.Time) error {
	pc.SetReadDeadline(t)
	return nil
}

func (pc *dnsOverTCPPacketConn) SetReadDeadline(t time.Time) error {
	pc.deadlineMu.Lock()
	pc.readDeadline = t
	pc.deadlineMu.Unlock()
	return nil
}

func (pc *dnsOverTCPPacketConn) SetWriteDeadline(time.Time) error { return nil }

EOGO

gofmt -w "${COMBO_DIR}/mobile.go"

echo "Installing pinned gomobile/gobind..."
# Do NOT use @latest here. A newer x/mobile snapshot can be missing/reshuffling
# golang.org/x/mobile/bind, which makes gobind fail with:
#   no Go package in golang.org/x/mobile/bind
# This revision is the one that was already present in your working tree and
# still contains the bind runtime package. Override only if you know the commit works:
#   GOMOBILE_VERSION=v0.0.0-... bash scripts/build_combo_aar.sh
MOBILE_VERSION="${GOMOBILE_VERSION:-v0.0.0-20260410095206-2cfb76559b7b}"

GOBIN_DIR="$(go env GOBIN)"
if [ -z "${GOBIN_DIR}" ]; then
  GOBIN_DIR="$(go env GOPATH)/bin"
fi
mkdir -p "${GOBIN_DIR}"
export PATH="${GOBIN_DIR}:${PATH}"

# Remove stale Windows binaries first; Git Bash may otherwise keep an older gobind.exe.
rm -f "${GOBIN_DIR}/gomobile" "${GOBIN_DIR}/gomobile.exe" "${GOBIN_DIR}/gobind" "${GOBIN_DIR}/gobind.exe"
go install "golang.org/x/mobile/cmd/gomobile@${MOBILE_VERSION}"
go install "golang.org/x/mobile/cmd/gobind@${MOBILE_VERSION}"

"${GOBIN_DIR}/gomobile" init

(
  cd "${COMBO_DIR}"
  echo "Downloading pinned Go modules..."
  go get "golang.org/x/mobile@${MOBILE_VERSION}"
  go mod tidy
  # Safety check: fail here with a clear message instead of inside gobind.
  go list -f '{{.Dir}}' golang.org/x/mobile/bind >/dev/null
  echo "Building combined AAR..."
  "${GOBIN_DIR}/gomobile" bind -target=android -androidapi 21 -ldflags "-s -w -checklinkname=0" -o "${OUT_AAR}" .
)

# Avoid duplicate gomobile runtime/classes if an old separate olcrtc.aar exists.
if [ -f "${PROJECT_ROOT}/app/libs/olcrtc.aar" ]; then
  mv "${PROJECT_ROOT}/app/libs/olcrtc.aar" "${PROJECT_ROOT}/app/libs/olcrtc.aar.disabled"
  echo "Moved old app/libs/olcrtc.aar to app/libs/olcrtc.aar.disabled to avoid duplicate gomobile classes."
fi

rm -rf "${PROJECT_ROOT}/app/src/main/jniLibs"

echo "OK: built ${OUT_AAR}"
echo "Now rebuild APK in Android Studio or run: gradle clean :app:assembleDebug"
