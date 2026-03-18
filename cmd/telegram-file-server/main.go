package main

import (
	"fmt"
	"log/slog"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	token := os.Getenv("TELEGRAM_FILE_SERVER_TOKEN")
	if token == "" {
		fmt.Fprintln(os.Stderr, "TELEGRAM_FILE_SERVER_TOKEN is required")
		os.Exit(1)
	}

	root := os.Getenv("TELEGRAM_FILE_SERVER_ROOT")
	if root == "" {
		root = "/data"
	}

	port := os.Getenv("TELEGRAM_FILE_SERVER_PORT")
	if port == "" {
		port = "8082"
	}

	readTimeout := parseDuration(os.Getenv("TELEGRAM_FILE_SERVER_READ_TIMEOUT"), 30*time.Second)
	writeTimeout := parseDuration(os.Getenv("TELEGRAM_FILE_SERVER_WRITE_TIMEOUT"), 10*time.Minute)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handleHealthz)
	mux.HandleFunc("GET /file", requireBearer(token, makeFileHandler(root)))

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
	}

	slog.Info("telegram-file-server starting", "port", port, "root", root)
	if err := srv.ListenAndServe(); err != nil {
		fmt.Fprintf(os.Stderr, "server error: %v\n", err)
		os.Exit(1)
	}
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func makeFileHandler(root string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		rawPath := r.URL.Query().Get("path")
		if rawPath == "" {
			http.Error(w, "bad path", http.StatusBadRequest)
			slog.Info("file request", "status", 400, "error", "missing path", "duration", time.Since(start))
			return
		}

		clean := filepath.Clean(rawPath)
		if !filepath.IsAbs(clean) || !strings.HasPrefix(clean, root+"/") && clean != root {
			http.Error(w, "forbidden", http.StatusForbidden)
			slog.Info("file request", "path", rawPath, "status", 403, "duration", time.Since(start))
			return
		}

		info, err := os.Stat(clean)
		if os.IsNotExist(err) {
			http.Error(w, "not found", http.StatusNotFound)
			slog.Info("file request", "path", clean, "status", 404, "duration", time.Since(start))
			return
		}
		if err != nil {
			http.Error(w, "internal server error", http.StatusInternalServerError)
			slog.Error("file stat error", "path", clean, "error", err, "duration", time.Since(start))
			return
		}
		if info.IsDir() {
			http.Error(w, "forbidden", http.StatusForbidden)
			slog.Info("file request", "path", clean, "status", 403, "error", "is directory", "duration", time.Since(start))
			return
		}

		f, err := os.Open(clean)
		if err != nil {
			http.Error(w, "internal server error", http.StatusInternalServerError)
			slog.Error("file open error", "path", clean, "error", err, "duration", time.Since(start))
			return
		}
		defer f.Close()

		ct := mime.TypeByExtension(filepath.Ext(clean))
		if ct == "" {
			ct = "application/octet-stream"
		}
		w.Header().Set("Content-Type", ct)

		http.ServeContent(w, r, info.Name(), info.ModTime(), f)
		slog.Info("file request", "path", clean, "status", 200, "duration", time.Since(start))
	}
}

func requireBearer(token string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") || strings.TrimPrefix(auth, "Bearer ") != token {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func parseDuration(s string, fallback time.Duration) time.Duration {
	if s == "" {
		return fallback
	}
	d, err := time.ParseDuration(s)
	if err != nil {
		return fallback
	}
	return d
}
