// Author: vld.lazar@proton.me
// Copyright: vld.lazar@proton.me
// Generated/edited with Claude

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sync"
	"sync/atomic"
)

type rpcRequest struct {
	Jsonrpc string `json:"jsonrpc"`
	ID      uint64 `json:"id"`
	Method  string `json:"method"`
	Params  []any  `json:"params"`
}

type rpcResponse struct {
	ID     uint64          `json:"id"`
	Result json.RawMessage `json:"result"`
	Error  *rpcError       `json:"error"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *rpcError) Error() string {
	return fmt.Sprintf("rpc error %d: %s", e.Code, e.Message)
}

// RpcClient manages a deltachat-rpc-server subprocess.
type RpcClient struct {
	cmd     *exec.Cmd
	enc     *json.Encoder
	mu      sync.Mutex
	nextID  atomic.Uint64
	pending map[uint64]chan *rpcResponse
	pendMu  sync.Mutex
}

func newRpcClient(accountsDir string) (*RpcClient, error) {
	cmd := exec.Command("deltachat-rpc-server")
	cmd.Stderr = os.Stderr
	if accountsDir != "" {
		cmd.Env = append(os.Environ(), "DC_ACCOUNTS_PATH="+accountsDir)
	}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("rpc stdin pipe: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("rpc stdout pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start deltachat-rpc-server: %w", err)
	}

	c := &RpcClient{
		cmd:     cmd,
		enc:     json.NewEncoder(stdin),
		pending: make(map[uint64]chan *rpcResponse),
	}

	go func() {
		scanner := bufio.NewScanner(stdout)
		scanner.Buffer(make([]byte, 4*1024*1024), 4*1024*1024)
		for scanner.Scan() {
			var resp rpcResponse
			if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
				continue
			}
			c.pendMu.Lock()
			ch, ok := c.pending[resp.ID]
			if ok {
				delete(c.pending, resp.ID)
			}
			c.pendMu.Unlock()
			if ok {
				ch <- &resp
			}
		}
	}()

	return c, nil
}

func (c *RpcClient) stop() {
	c.cmd.Process.Kill()
	c.cmd.Wait()
}

func (c *RpcClient) call(method string, params ...any) (json.RawMessage, error) {
	id := c.nextID.Add(1)
	req := rpcRequest{
		Jsonrpc: "2.0",
		ID:      id,
		Method:  method,
		Params:  params,
	}

	ch := make(chan *rpcResponse, 1)
	c.pendMu.Lock()
	c.pending[id] = ch
	c.pendMu.Unlock()

	c.mu.Lock()
	err := c.enc.Encode(req)
	c.mu.Unlock()
	if err != nil {
		return nil, fmt.Errorf("rpc send %s: %w", method, err)
	}

	resp := <-ch
	if resp.Error != nil {
		return nil, resp.Error
	}
	return resp.Result, nil
}

func callResult[T any](c *RpcClient, method string, params ...any) (T, error) {
	var zero T
	raw, err := c.call(method, params...)
	if err != nil {
		return zero, err
	}
	var result T
	if err := json.Unmarshal(raw, &result); err != nil {
		return zero, fmt.Errorf("rpc decode %s: %w", method, err)
	}
	return result, nil
}
