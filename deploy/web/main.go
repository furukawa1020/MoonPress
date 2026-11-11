// The HTTPS edge authenticates the browser and forwards bounded HTTP requests
// to MoonPress. Editing, validation, rendering and publication stay in MoonBit.
package main

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type gateway struct {
	origin   *url.URL
	password [sha256.Size]byte
	upstream *url.URL
	proxy    http.Handler
	client   *http.Client
	editor   chan struct{}
	public   chan struct{}
}

func newGateway(origin, upstream *url.URL, password string) *gateway {
	transport := &http.Transport{
		DialContext:       (&net.Dialer{Timeout: 2 * time.Second}).DialContext,
		DisableKeepAlives: true, DisableCompression: true,
		ResponseHeaderTimeout: 25 * time.Second,
	}
	proxy := &httputil.ReverseProxy{
		Rewrite: func(request *httputil.ProxyRequest) {
			request.SetURL(upstream)
			request.Out.Host = upstream.Host
			request.Out.Header.Del("Authorization")
			request.Out.Header.Del("Proxy-Authorization")
			path := request.In.URL.EscapedPath()
			public := strings.HasPrefix(path, "/site/")
			if public {
				request.Out.Header.Del("Cookie")
			}
			if public || strings.HasPrefix(path, "/preview/") {
				request.Out.Header.Del("Origin")
				request.Out.Header.Del("Sec-Fetch-Site")
			} else if request.In.Method == http.MethodGet &&
				request.In.Header.Get("Sec-Fetch-Mode") == "navigate" &&
				request.In.Header.Get("Sec-Fetch-Dest") == "document" {
				request.Out.Header.Del("Sec-Fetch-Site")
			}
		},
		Transport: transport,
		ModifyResponse: func(response *http.Response) error {
			path := response.Request.URL.EscapedPath()
			if strings.HasPrefix(path, "/preview/") {
				response.Header.Set("Cache-Control", "no-store")
			} else if strings.HasPrefix(path, "/site/") &&
				(response.StatusCode == http.StatusOK || response.StatusCode == http.StatusNotModified) {
				response.Header.Set("Cache-Control", "public, max-age=0, must-revalidate")
			}
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, _ *http.Request, _ error) {
			http.Error(w, "MoonPress is temporarily unavailable.", http.StatusServiceUnavailable)
		},
	}
	return &gateway{
		origin: origin, password: sha256.Sum256([]byte(password)), upstream: upstream,
		proxy: proxy, client: &http.Client{Transport: transport, Timeout: 3 * time.Second},
		editor: make(chan struct{}, 4), public: make(chan struct{}, 8),
	}
}

func (g *gateway) healthy(ctx context.Context) bool {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, g.upstream.String()+"/web-health", nil)
	if err != nil {
		return false
	}
	response, err := g.client.Do(request)
	if err != nil {
		return false
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 4))
	return err == nil && response.StatusCode == http.StatusOK && string(body) == "OK\n"
}

func (g *gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := r.URL.EscapedPath()
	w.Header().Set("X-Content-Type-Options", "nosniff")
	if path == "/healthz" && r.Method == http.MethodGet && r.ContentLength == 0 {
		w.Header().Set("Cache-Control", "no-store")
		if !g.healthy(r.Context()) {
			http.Error(w, "Unavailable.", http.StatusServiceUnavailable)
			return
		}
		fmt.Fprintln(w, "OK")
		return
	}
	if r.Host != g.origin.Host || r.URL.IsAbs() {
		http.Error(w, "Invalid host.", http.StatusBadRequest)
		return
	}
	w.Header().Set("Strict-Transport-Security", "max-age=31536000")
	public := path == "/site" || strings.HasPrefix(path, "/site/")
	preview := strings.HasPrefix(path, "/preview/") || (path == "/preview" && r.Method != http.MethodPost)
	if !public {
		user, password, ok := r.BasicAuth()
		actual := sha256.Sum256([]byte(password))
		if !ok || user != "admin" || len(r.Header.Values("Authorization")) != 1 ||
			subtle.ConstantTimeCompare(actual[:], g.password[:]) != 1 {
			w.Header().Set("WWW-Authenticate", `Basic realm="MoonPress", charset="UTF-8"`)
			w.Header().Set("Cache-Control", "no-store")
			http.Error(w, "Sign in to MoonPress.", http.StatusUnauthorized)
			return
		}
	}
	read := r.Method == http.MethodGet || (r.Method == http.MethodHead && (public || preview))
	if !read && (public || preview || r.Method != http.MethodPost) {
		http.Error(w, "Method not allowed.", http.StatusMethodNotAllowed)
		return
	}
	if r.ContentLength < 0 || len(r.TransferEncoding) != 0 ||
		r.Header.Get("Content-Encoding") != "" || r.Header.Get("Expect") != "" ||
		(read && r.ContentLength != 0) {
		http.Error(w, "Invalid request body.", http.StatusBadRequest)
		return
	}
	limit := int64(256 << 10)
	if path == "/upload" || path == "/replace-media" {
		limit = 8 << 20
	}
	if r.ContentLength > limit {
		http.Error(w, "Request body too large.", http.StatusRequestEntityTooLarge)
		return
	}
	if r.Method == http.MethodPost && (len(r.Header.Values("Origin")) != 1 ||
		r.Header.Get("Origin") != g.origin.String() || r.Header.Get("Sec-Fetch-Site") == "cross-site") {
		http.Error(w, "Invalid form origin.", http.StatusForbidden)
		return
	}
	if path == "/site" || (path == "/preview" && preview) {
		http.Redirect(w, r, path+"/", http.StatusPermanentRedirect)
		return
	}
	if path == "/web-health" {
		http.NotFound(w, r)
		return
	}
	slots := g.editor
	if public {
		slots = g.public
	}
	select {
	case slots <- struct{}{}:
		defer func() { <-slots }()
	default:
		http.Error(w, "MoonPress is busy. Retry shortly.", http.StatusServiceUnavailable)
		return
	}
	g.proxy.ServeHTTP(w, r)
}

func setting(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func publicOrigin() (*url.URL, error) {
	raw := os.Getenv("MOONPRESS_WEB_ORIGIN")
	if raw == "" {
		domain := setting("RAILWAY_PUBLIC_DOMAIN", os.Getenv("RENDER_EXTERNAL_HOSTNAME"))
		raw = "https://" + domain
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme != "https" || parsed.Hostname() == "" ||
		parsed.Path != "" || parsed.User != nil || parsed.RawQuery != "" || parsed.ForceQuery ||
		parsed.Fragment != "" || parsed.String() != raw || strings.ToLower(parsed.Host) != parsed.Host {
		return nil, errors.New("set MOONPRESS_WEB_ORIGIN to the canonical HTTPS origin without a trailing slash")
	}
	return parsed, nil
}

func servicePort(name, fallback string) (string, error) {
	raw := setting(name, fallback)
	port, err := strconv.Atoi(raw)
	if err != nil || port < 1024 || port > 65534 || strconv.Itoa(port) != raw {
		return "", fmt.Errorf("%s must be a port between 1024 and 65534", name)
	}
	return raw, nil
}

func openSite(root, executable string) (string, *os.File, error) {
	info, err := os.Lstat(root)
	if err != nil || !info.IsDir() {
		return "", nil, errors.New("mount a writable data directory for MoonPress")
	}
	lock, err := os.OpenFile(filepath.Join(root, ".moonpress-web.lock"), os.O_RDWR|os.O_CREATE|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0600)
	if err != nil {
		return "", nil, fmt.Errorf("open site lock: %w", err)
	}
	lockInfo, err := lock.Stat()
	if err != nil || !lockInfo.Mode().IsRegular() || syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB) != nil {
		lock.Close()
		return "", nil, errors.New("site data already has an active writer or its lock is invalid")
	}
	site := filepath.Join(root, "site")
	info, err = os.Lstat(site)
	if errors.Is(err, os.ErrNotExist) {
		init := exec.Command(executable, "init", site)
		init.Env = []string{}
		init.Stdout, init.Stderr = os.Stdout, os.Stderr
		err = init.Run()
	} else if err == nil && !info.IsDir() {
		err = errors.New("site must be a real directory")
	}
	if err != nil {
		lock.Close()
		return "", nil, fmt.Errorf("initialize site: %w", err)
	}
	return site, lock, nil
}

func run() error {
	origin, err := publicOrigin()
	if err != nil {
		return err
	}
	password := os.Getenv("MOONPRESS_ADMIN_PASSWORD")
	if len(password) < 24 || len(password) > 256 {
		return errors.New("set MOONPRESS_ADMIN_PASSWORD to a strong password of 24–256 bytes")
	}
	port, err := servicePort("PORT", "8080")
	if err != nil {
		return err
	}
	backendPort, err := servicePort("MOONPRESS_BACKEND_PORT", "18081")
	if err != nil {
		return err
	}
	backendNumber, _ := strconv.Atoi(backendPort)
	if port == backendPort || port == strconv.Itoa(backendNumber+1) {
		return errors.New("the web port overlaps the private MoonPress ports")
	}
	cert, key := os.Getenv("MOONPRESS_TLS_CERT"), os.Getenv("MOONPRESS_TLS_KEY")
	if (cert == "") != (key == "") {
		return errors.New("configure both MOONPRESS_TLS_CERT and MOONPRESS_TLS_KEY")
	}
	executable := setting("MOONPRESS_BIN", "/usr/local/bin/moonpress")
	root := setting("MOONPRESS_DATA_DIR", "/data")
	site, lock, err := openSite(root, executable)
	if err != nil {
		return err
	}
	defer lock.Close()

	backend := exec.Command(executable, "admin", site, backendPort)
	backend.Env = []string{"MOONPRESS_WEB_ORIGIN=" + origin.String()}
	backend.Stdout, backend.Stderr = os.Stdout, os.Stderr
	if err := backend.Start(); err != nil {
		return fmt.Errorf("start MoonPress: %w", err)
	}
	backendExit := make(chan error, 1)
	go func() { backendExit <- backend.Wait() }()
	upstream := &url.URL{Scheme: "http", Host: "127.0.0.1:" + backendPort}
	server := &http.Server{
		Addr: ":" + port, Handler: newGateway(origin, upstream, password),
		ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 20 * time.Second,
		WriteTimeout: 35 * time.Second, IdleTimeout: 20 * time.Second, MaxHeaderBytes: 16 << 10,
	}
	stop, release := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer release()
	serverExit := make(chan error, 1)
	go func() {
		if cert != "" {
			serverExit <- server.ListenAndServeTLS(cert, key)
		} else {
			serverExit <- server.ListenAndServe()
		}
	}()
	log.Print("MoonPress web gateway started")
	var result error
	select {
	case err := <-backendExit:
		server.Close()
		return fmt.Errorf("MoonPress backend exited: %v", err)
	case result = <-serverExit:
	case <-stop.Done():
	}
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		server.Close()
	}
	backend.Process.Signal(syscall.SIGTERM)
	select {
	case <-backendExit:
	case <-time.After(5 * time.Second):
		backend.Process.Kill()
		<-backendExit
	}
	return result
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}
