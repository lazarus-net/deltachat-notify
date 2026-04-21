// Author: vld.lazar@proton.me
// Copyright: vld.lazar@proton.me
// Generated/edited with Claude

package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type ServiceConfig struct {
	Name    string
	Token   string
	GroupID int
}

type Config struct {
	BotAddress string
	BotPassword string
	Listen     string
	Services   map[string]*ServiceConfig // token -> service
}

// parseBotConf reads address and password from a simple "key value" file.
func parseBotConf(path string) (address, password string, err error) {
	f, err := os.Open(path)
	if err != nil {
		return "", "", fmt.Errorf("open bot config %s: %w", path, err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, " ", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		switch key {
		case "address":
			address = val
		case "password":
			password = val
		}
	}
	if address == "" || password == "" {
		return "", "", fmt.Errorf("bot config %s: missing address or password", path)
	}
	return address, password, nil
}

// parseServicesConf reads service definitions: "name token group_id" per line.
func parseServicesConf(path string) (map[string]*ServiceConfig, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open services config %s: %w", path, err)
	}
	defer f.Close()

	services := make(map[string]*ServiceConfig)
	scanner := bufio.NewScanner(f)
	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) != 3 {
			return nil, fmt.Errorf("services config line %d: expected 'name token group_id'", lineNum)
		}
		var groupID int
		if _, err := fmt.Sscanf(parts[2], "%d", &groupID); err != nil {
			return nil, fmt.Errorf("services config line %d: invalid group_id %q", lineNum, parts[2])
		}
		svc := &ServiceConfig{
			Name:    parts[0],
			Token:   parts[1],
			GroupID: groupID,
		}
		services[parts[1]] = svc
	}
	return services, nil
}

func loadConfig(botConf, servicesConf, listen string) (*Config, error) {
	address, password, err := parseBotConf(botConf)
	if err != nil {
		return nil, err
	}
	services, err := parseServicesConf(servicesConf)
	if err != nil {
		return nil, err
	}
	return &Config{
		BotAddress:  address,
		BotPassword: password,
		Listen:      listen,
		Services:    services,
	}, nil
}
