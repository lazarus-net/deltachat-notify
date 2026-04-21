// Author: vld.lazar@proton.me
// Copyright: vld.lazar@proton.me
// Generated/edited with Claude

package main

import (
	"fmt"
)

type Bot struct {
	rpc       *RpcClient
	accountID uint32
}

func newBot(address, password, accountsDir string) (*Bot, error) {
	rpc, err := newRpcClient(accountsDir)
	if err != nil {
		return nil, err
	}

	accountID, err := findOrCreateAccount(rpc, address, password)
	if err != nil {
		rpc.stop()
		return nil, err
	}

	return &Bot{rpc: rpc, accountID: accountID}, nil
}

func findOrCreateAccount(rpc *RpcClient, address, password string) (uint32, error) {
	ids, err := callResult[[]uint32](rpc, "get_all_account_ids")
	if err != nil {
		return 0, fmt.Errorf("get accounts: %w", err)
	}

	for _, id := range ids {
		addr, err := callResult[*string](rpc, "get_config", id, "addr")
		if err != nil || addr == nil {
			continue
		}
		if *addr == address {
			return id, nil
		}
	}

	id, err := callResult[uint32](rpc, "add_account")
	if err != nil {
		return 0, fmt.Errorf("add account: %w", err)
	}

	if _, err := rpc.call("set_config", id, "addr", address); err != nil {
		return 0, fmt.Errorf("set addr: %w", err)
	}
	if _, err := rpc.call("set_config", id, "mail_pw", password); err != nil {
		return 0, fmt.Errorf("set password: %w", err)
	}
	if _, err := rpc.call("configure", id); err != nil {
		return 0, fmt.Errorf("configure account: %w", err)
	}

	return id, nil
}

func (b *Bot) stop() {
	b.rpc.call("stop_io", b.accountID) //nolint:errcheck
	b.rpc.stop()
}

func (b *Bot) startIO() error {
	_, err := b.rpc.call("start_io", b.accountID)
	return err
}

func (b *Bot) sendText(chatID int, text string) error {
	type msgData struct {
		Text string `json:"text"`
	}
	_, err := b.rpc.call("send_msg", b.accountID, uint32(chatID), msgData{Text: text})
	return err
}

func (b *Bot) createGroup(name string) (int, error) {
	chatID, err := callResult[uint32](b.rpc, "create_group_chat", b.accountID, name, false)
	if err != nil {
		return 0, fmt.Errorf("create group %q: %w", name, err)
	}
	return int(chatID), nil
}

func (b *Bot) addMember(chatID int, email string) error {
	contactID, err := callResult[uint32](b.rpc, "create_contact", b.accountID, email, nil)
	if err != nil {
		return fmt.Errorf("create contact %q: %w", email, err)
	}
	_, err = b.rpc.call("add_contact_to_chat", b.accountID, uint32(chatID), contactID)
	return err
}

func (b *Bot) getInviteLink(chatID int) (string, error) {
	chatIDPtr := uint32(chatID)
	return callResult[string](b.rpc, "get_chat_securejoin_qr_code", b.accountID, &chatIDPtr)
}
