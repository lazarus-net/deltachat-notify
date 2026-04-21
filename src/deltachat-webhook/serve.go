// Author: vld.lazar@proton.me
// Copyright: vld.lazar@proton.me
// Generated/edited with Claude

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
)

type webhookRequest struct {
	Text string `json:"text"`
}

func runServer(cfg *Config, bot *Bot) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/webhook", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		token := strings.TrimPrefix(auth, "Bearer ")

		svc, ok := cfg.Services[token]
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		body, err := io.ReadAll(io.LimitReader(r.Body, 64*1024))
		if err != nil {
			http.Error(w, "read error", http.StatusBadRequest)
			return
		}

		var req webhookRequest
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "invalid JSON", http.StatusBadRequest)
			return
		}
		if req.Text == "" {
			http.Error(w, "text is required", http.StatusBadRequest)
			return
		}

		if err := bot.sendText(svc.GroupID, req.Text); err != nil {
			log.Printf("ERROR send to group %d (service %s): %v", svc.GroupID, svc.Name, err)
			http.Error(w, "send failed", http.StatusInternalServerError)
			return
		}

		log.Printf("sent message to group %d (service %s)", svc.GroupID, svc.Name)
		w.WriteHeader(http.StatusNoContent)
	})

	log.Printf("listening on %s", cfg.Listen)
	return http.ListenAndServe(cfg.Listen, mux)
}

func printUsage() {
	fmt.Print(`deltachat-webhook - send Delta Chat group messages via HTTP webhook

Usage:
  deltachat-webhook serve --bot <bot.conf> --services <services.conf> [--listen <addr>]
  deltachat-webhook create-group --bot <bot.conf> --name <name> [--admin <email>]
  deltachat-webhook invite --bot <bot.conf> --group <group_id>
  deltachat-webhook add-member --bot <bot.conf> --group <group_id> --email <email>

serve flags:
  --bot       path to bot credentials file (address + password)
  --services  path to services config file (name token group_id per line)
  --listen    listen address (default: 127.0.0.1:8095)

Bot credentials file format (bot.conf):
  address  bot@deltachat.example.org
  password secretpassword

Services config file format (services.conf):
  # name token group_id
  service-a abc123def456 15
  service-b xyz789ghi012 22

Webhook usage:
  POST /webhook
  Authorization: Bearer <token>
  {"text": "notification message"}
`)
}
