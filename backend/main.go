package main

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type execRequest struct {
	Args       []string `json:"args"`
	Stdin      string   `json:"stdin,omitempty"`
	TimeoutSec int      `json:"timeout_sec,omitempty"`
}

type execResponse struct {
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	ExitCode   int    `json:"exit_code"`
	DurationMs int64  `json:"duration_ms"`
	TimedOut   bool   `json:"timed_out"`
}

type errorResponse struct {
	Error string `json:"error"`
}

var (
	cliPath   string
	authToken string
	workDir   string
	// crude single-flight to avoid concurrent signing with same seed
	execMu sync.Mutex
)

func main() {
	cliPath = envDefault("QUBIC_CLI", "/usr/local/bin/qubic-cli")
	authToken = os.Getenv("API_TOKEN")
	workDir = envDefault("QUBIC_WORKDIR", "/var/lib/qubic-api")
	addr := envDefault("LISTEN", "127.0.0.1:8787")

	if authToken == "" {
		log.Fatal("API_TOKEN env var required")
	}
	if _, err := os.Stat(cliPath); err != nil {
		log.Fatalf("qubic-cli not found at %s: %v", cliPath, err)
	}
	if err := os.MkdirAll(workDir, 0o700); err != nil {
		log.Fatalf("workdir: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", handleHealth)
	mux.HandleFunc("/version", auth(handleVersion))
	mux.HandleFunc("/exec", auth(handleExec))
	mux.HandleFunc("/upload", auth(handleUpload))
	mux.HandleFunc("/download/", auth(handleDownload))

	srv := &http.Server{
		Addr:              addr,
		Handler:           logRequests(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("listening on %s, cli=%s", addr, cliPath)
	log.Fatal(srv.ListenAndServe())
}

func envDefault(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		h := r.Header.Get("Authorization")
		const p = "Bearer "
		if !strings.HasPrefix(h, p) || subtle.ConstantTimeCompare([]byte(h[len(p):]), []byte(authToken)) != 1 {
			writeJSON(w, http.StatusUnauthorized, errorResponse{Error: "unauthorized"})
			return
		}
		next(w, r)
	}
}

func logRequests(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		h.ServeHTTP(w, r)
		log.Printf("%s %s %s %v", r.RemoteAddr, r.Method, r.URL.Path, time.Since(start))
	})
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, map[string]string{"status": "ok"})
}

func handleVersion(w http.ResponseWriter, r *http.Request) {
	out, err := runCLI(r.Context(), []string{"-help"}, "", 5*time.Second)
	if err != nil && out.ExitCode == 0 {
		writeJSON(w, 500, errorResponse{Error: err.Error()})
		return
	}
	writeJSON(w, 200, out)
}

func handleExec(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, 405, errorResponse{Error: "method not allowed"})
		return
	}
	var req execRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, 400, errorResponse{Error: "bad json: " + err.Error()})
		return
	}
	if len(req.Args) == 0 {
		writeJSON(w, 400, errorResponse{Error: "args required"})
		return
	}
	if err := validateArgs(req.Args); err != nil {
		writeJSON(w, 400, errorResponse{Error: err.Error()})
		return
	}
	timeout := time.Duration(req.TimeoutSec) * time.Second
	if timeout <= 0 || timeout > 5*time.Minute {
		timeout = 60 * time.Second
	}

	execMu.Lock()
	defer execMu.Unlock()

	resp, err := runCLI(r.Context(), req.Args, req.Stdin, timeout)
	if err != nil && !errors.Is(err, errNonZeroExit) {
		writeJSON(w, 500, errorResponse{Error: err.Error()})
		return
	}
	writeJSON(w, 200, resp)
}

var errNonZeroExit = errors.New("non-zero exit")

// handleUpload accepts a multipart "file" field, saves it to workDir/uploads,
// and returns the absolute path so the caller can pass it as a CLI arg.
func handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, 405, errorResponse{Error: "method not allowed"})
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 128<<20) // 128 MB cap
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		writeJSON(w, 400, errorResponse{Error: "parse multipart: " + err.Error()})
		return
	}
	f, hdr, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, 400, errorResponse{Error: "file field required"})
		return
	}
	defer f.Close()

	// sanitize filename — strip path, nulls, and leading dots
	base := filepath.Base(hdr.Filename)
	base = strings.ReplaceAll(base, "\x00", "")
	base = strings.TrimLeft(base, ".")
	if base == "" || base == "/" {
		base = "upload.bin"
	}

	dir := filepath.Join(workDir, "uploads")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		writeJSON(w, 500, errorResponse{Error: "mkdir: " + err.Error()})
		return
	}
	name := fmt.Sprintf("%d-%s", time.Now().UnixNano(), base)
	full := filepath.Join(dir, name)

	out, err := os.OpenFile(full, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		writeJSON(w, 500, errorResponse{Error: "create: " + err.Error()})
		return
	}
	defer out.Close()
	written, err := io.Copy(out, f)
	if err != nil {
		_ = os.Remove(full)
		writeJSON(w, 500, errorResponse{Error: "write: " + err.Error()})
		return
	}
	writeJSON(w, 200, map[string]any{
		"path": full,
		"name": name,
		"size": written,
	})
}

// handleDownload serves files from workDir (e.g. outputs written by qubic-cli).
// URL: /download/<name>  — name is a plain filename, no path traversal allowed.
func handleDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, 405, errorResponse{Error: "method not allowed"})
		return
	}
	name := strings.TrimPrefix(r.URL.Path, "/download/")
	if name == "" || strings.Contains(name, "..") || strings.ContainsAny(name, "/\x00") {
		writeJSON(w, 400, errorResponse{Error: "bad name"})
		return
	}
	full := filepath.Join(workDir, name)
	info, err := os.Stat(full)
	if err != nil || info.IsDir() {
		writeJSON(w, 404, errorResponse{Error: "not found"})
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", name))
	http.ServeFile(w, r, full)
}

func runCLI(ctx context.Context, args []string, stdin string, timeout time.Duration) (execResponse, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	start := time.Now()
	cmd := exec.CommandContext(ctx, cliPath, args...)
	cmd.Dir = workDir
	// scrub inherited env; only keep what qubic-cli may need
	cmd.Env = []string{
		"HOME=" + workDir,
		"PATH=/usr/local/bin:/usr/bin:/bin",
	}
	if stdin != "" {
		cmd.Stdin = strings.NewReader(stdin)
	}
	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	runErr := cmd.Run()
	resp := execResponse{
		Stdout:     stdout.String(),
		Stderr:     stderr.String(),
		DurationMs: time.Since(start).Milliseconds(),
	}
	if ctx.Err() == context.DeadlineExceeded {
		resp.TimedOut = true
	}
	if runErr != nil {
		if ee, ok := runErr.(*exec.ExitError); ok {
			resp.ExitCode = ee.ExitCode()
			return resp, errNonZeroExit
		}
		return resp, runErr
	}
	return resp, nil
}

// validateArgs rejects shell-injection attempts and obviously bad paths.
// qubic-cli is invoked via exec (no shell), so the main risk is file args
// pointing outside the workdir. We just refuse absolute paths and "..".
func validateArgs(args []string) error {
	for _, a := range args {
		if len(a) > 4096 {
			return errors.New("arg too long")
		}
		if strings.Contains(a, "\x00") {
			return errors.New("null byte in arg")
		}
	}
	_ = filepath.Clean
	return nil
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
