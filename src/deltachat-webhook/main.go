// Author: vld.lazar@proton.me
// Copyright: vld.lazar@proton.me
// Generated/edited with Claude

package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "serve":
		cmdServe(os.Args[2:])
	case "create-group":
		cmdCreateGroup(os.Args[2:])
	case "invite":
		cmdInvite(os.Args[2:])
	case "add-member":
		cmdAddMember(os.Args[2:])
	default:
		printUsage()
		os.Exit(1)
	}
}

func cmdServe(args []string) {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	botConf := fs.String("bot", "", "bot credentials file")
	servicesConf := fs.String("services", "", "services config file")
	listen := fs.String("listen", "127.0.0.1:8095", "listen address")
	accountsDir := fs.String("accounts-dir", "", "deltachat-rpc-server accounts directory")
	fs.Parse(args)

	if *botConf == "" || *servicesConf == "" {
		fmt.Fprintln(os.Stderr, "ERROR: --bot and --services are required")
		os.Exit(1)
	}

	cfg, err := loadConfig(*botConf, *servicesConf, *listen)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	bot, err := newBot(cfg.BotAddress, cfg.BotPassword, *accountsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: connect bot: %v\n", err)
		os.Exit(1)
	}
	defer bot.stop()

	if err := bot.startIO(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: start IO: %v\n", err)
		os.Exit(1)
	}

	if err := runServer(cfg, bot); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: server: %v\n", err)
		os.Exit(1)
	}
}

func cmdCreateGroup(args []string) {
	fs := flag.NewFlagSet("create-group", flag.ExitOnError)
	botConf := fs.String("bot", "", "bot credentials file")
	name := fs.String("name", "", "group name")
	admin := fs.String("admin", "", "admin email to add as member")
	accountsDir := fs.String("accounts-dir", "", "deltachat-rpc-server accounts directory")
	fs.Parse(args)

	if *botConf == "" || *name == "" {
		fmt.Fprintln(os.Stderr, "ERROR: --bot and --name are required")
		os.Exit(1)
	}

	address, password, err := parseBotConf(*botConf)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	bot, err := newBot(address, password, *accountsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: connect bot: %v\n", err)
		os.Exit(1)
	}
	defer bot.stop()

	if err := bot.startIO(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: start IO: %v\n", err)
		os.Exit(1)
	}

	groupID, err := bot.createGroup(*name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	if *admin != "" {
		if err := bot.addMember(groupID, *admin); err != nil {
			fmt.Fprintf(os.Stderr, "WARNING: add admin member: %v\n", err)
		}
	}

	inviteLink, err := bot.getInviteLink(groupID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "WARNING: get invite link: %v\n", err)
	}

	fmt.Printf("group_id=%d\n", groupID)
	if inviteLink != "" {
		fmt.Printf("invite=%s\n", inviteLink)
	}
}

func cmdInvite(args []string) {
	fs := flag.NewFlagSet("invite", flag.ExitOnError)
	botConf := fs.String("bot", "", "bot credentials file")
	groupID := fs.Int("group", 0, "group ID")
	accountsDir := fs.String("accounts-dir", "", "deltachat-rpc-server accounts directory")
	fs.Parse(args)

	if *botConf == "" || *groupID == 0 {
		fmt.Fprintln(os.Stderr, "ERROR: --bot and --group are required")
		os.Exit(1)
	}

	address, password, err := parseBotConf(*botConf)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	bot, err := newBot(address, password, *accountsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: connect bot: %v\n", err)
		os.Exit(1)
	}
	defer bot.stop()

	if err := bot.startIO(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: start IO: %v\n", err)
		os.Exit(1)
	}

	link, err := bot.getInviteLink(*groupID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(link)
}

func cmdAddMember(args []string) {
	fs := flag.NewFlagSet("add-member", flag.ExitOnError)
	botConf := fs.String("bot", "", "bot credentials file")
	groupID := fs.Int("group", 0, "group ID")
	email := fs.String("email", "", "member email")
	accountsDir := fs.String("accounts-dir", "", "deltachat-rpc-server accounts directory")
	fs.Parse(args)

	if *botConf == "" || *groupID == 0 || *email == "" {
		fmt.Fprintln(os.Stderr, "ERROR: --bot, --group and --email are required")
		os.Exit(1)
	}

	address, password, err := parseBotConf(*botConf)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}

	bot, err := newBot(address, password, *accountsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: connect bot: %v\n", err)
		os.Exit(1)
	}
	defer bot.stop()

	if err := bot.startIO(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: start IO: %v\n", err)
		os.Exit(1)
	}

	if err := bot.addMember(*groupID, *email); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Added %s to group %d\n", *email, *groupID)
}
