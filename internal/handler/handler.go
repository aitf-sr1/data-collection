package handler

import (
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/agung/fer-datacollect/internal/broadcast"
	"github.com/agung/fer-datacollect/internal/session"
	"github.com/agung/fer-datacollect/internal/upload"
)

type Handler struct {
	broadcaster *broadcast.Broadcaster
	session     *session.State
	dataDir     string
	adminToken  string
	clientFS    embed.FS
}

func New(bc *broadcast.Broadcaster, sess *session.State, dataDir, adminToken string, clientFS embed.FS) *Handler {
	return &Handler{
		broadcaster: bc,
		session:     sess,
		dataDir:     dataDir,
		adminToken:  adminToken,
		clientFS:    clientFS,
	}
}

func (h *Handler) GetClientFS() fs.FS {
	sub, _ := fs.Sub(h.clientFS, "client")
	return sub
}

func (h *Handler) ServeRecorder(w http.ResponseWriter, r *http.Request) {
	data, err := h.clientFS.ReadFile("client/recorder.html")
	if err != nil {
		http.Error(w, "recorder not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(data)
}

func (h *Handler) ServeAdmin(w http.ResponseWriter, r *http.Request) {
	if !h.validateToken(r) {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	data, err := h.clientFS.ReadFile("client/admin.html")
	if err != nil {
		http.Error(w, "admin not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(data)
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"ok":true}`))
}

func (h *Handler) Status(w http.ResponseWriter, r *http.Request) {
	subjects := h.session.GetAll()
	subjectsJSON := make(map[string]any)

	for id, sub := range subjects {
		subjectsJSON[id] = map[string]any{
			"connected":        sub.Connected,
			"name":             sub.Name,
			"scenarios_done":   sub.ScenariosDone,
			"current_scenario": sub.CurrentScenario,
			"bytes_received":   sub.BytesReceived,
			"last_seen":        sub.LastSeen.Format(time.RFC3339),
		}
	}

	var startedAt any = nil
	if h.session.IsStarted() {
		startedAt = h.session.StartedAt().Format(time.RFC3339)
	}

	resp := map[string]any{
		"started":           h.session.IsStarted(),
		"started_at":        startedAt,
		"connected_clients": h.session.ConnectedCount(),
		"subjects":          subjectsJSON,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *Handler) SSE(w http.ResponseWriter, r *http.Request) {
	subjectID := r.URL.Query().Get("subject_id")
	if err := upload.ValidateSubjectID(subjectID); err != nil {
		http.Error(w, `{"error":"invalid subject_id"}`, http.StatusBadRequest)
		return
	}

	name := r.URL.Query().Get("name")
	if name != "" {
		h.session.SetName(subjectID, name)
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	h.session.Connect(subjectID)
	ch := h.broadcaster.Subscribe(subjectID)

	defer func() {
		h.broadcaster.Unsubscribe(subjectID)
		h.session.Disconnect(subjectID)
	}()

	_, _ = fmt.Fprintf(w, ": connected\n\n")
	flusher.Flush()

	if h.session.IsStarted() {
		event := broadcast.Event{
			Type:      "start",
			Timestamp: h.session.StartedAt().UnixMilli(),
		}
		data, _ := json.Marshal(event)
		_, _ = fmt.Fprintf(w, "data: %s\n\n", data)
		flusher.Flush()
	}

	ctx := r.Context()
	for {
		select {
		case event, ok := <-ch:
			if !ok {
				return
			}
			data, _ := json.Marshal(event)
			_, _ = fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()
		case <-ctx.Done():
			return
		}
	}
}

func (h *Handler) StartSession(w http.ResponseWriter, r *http.Request) {
	if !h.validateToken(r) {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	if h.session.IsStarted() {
		w.WriteHeader(http.StatusConflict)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"error":"session already started"}`))
		return
	}

	h.session.MarkStarted()

	event := broadcast.Event{
		Type:      "start",
		Timestamp: time.Now().UnixMilli(),
	}
	h.broadcaster.Broadcast(event)

	count := h.broadcaster.Count()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]int{"sent_to": count})
}

func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	subjectID := chi.URLParam(r, "subjectID")
	scenario := chi.URLParam(r, "scenario")

	// Track that this scenario is being recorded
	h.session.SetCurrentScenario(subjectID, scenario)

	n, err := upload.WriteChunked(h.dataDir, subjectID, scenario, r.Body)
	if err != nil {
		if strings.Contains(err.Error(), "invalid") {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusBadRequest)
			return
		}
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
		return
	}

	h.session.RecordUpload(subjectID, scenario, n)
	// Clear current scenario after upload completes
	h.session.SetCurrentScenario(subjectID, "")

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]int64{"bytes": n})
}

func (h *Handler) validateToken(r *http.Request) bool {
	auth := r.Header.Get("Authorization")
	if auth == "" {
		auth = r.URL.Query().Get("token")
		return auth == h.adminToken
	}

	parts := strings.SplitN(auth, " ", 2)
	if len(parts) != 2 || parts[0] != "Bearer" {
		return false
	}
	return parts[1] == h.adminToken
}
