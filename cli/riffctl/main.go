package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/shadowfax92/riff/cli/riffctl/internal/riffs"
	"github.com/shadowfax92/riff/cli/riffctl/internal/templates"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		printUsage()
		return nil
	}
	if args[0] == "create" {
		if len(args) >= 2 && args[1] == "template" {
			return createTemplate(args[2:])
		}
		return createRiff(args[1:])
	}
	return fmt.Errorf("unknown command: %s", strings.Join(args, " "))
}

func createTemplate(args []string) error {
	opts, err := parseCreateAgentArgs(args)
	if err != nil {
		return err
	}
	result, err := templates.CreateAgentTemplate(opts)
	if err != nil {
		return err
	}
	fmt.Printf("Created riff template: %s\n", result.Path)
	fmt.Printf("  %s\n", result.Prompt)
	for _, file := range result.RoleFiles {
		fmt.Printf("  %s\n", file)
	}
	return nil
}

func createRiff(args []string) error {
	opts, err := parseCreateRiffArgs(args)
	if err != nil {
		return err
	}
	result, err := riffs.CreateRiff(opts)
	if err != nil {
		return err
	}
	fmt.Printf("Created riff: %s\n", result.Path)
	fmt.Printf("  id: %s\n", result.ID)
	return nil
}

func parseCreateAgentArgs(args []string) (templates.CreateAgentOptions, error) {
	opts := templates.CreateAgentOptions{Roles: 1}
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--roles", "-r":
			value, ok := nextValue(args, &i, "--roles")
			if !ok {
				return opts, fmt.Errorf("--roles requires a value")
			}
			roles, err := strconv.Atoi(value)
			if err != nil {
				return opts, fmt.Errorf("invalid --roles value %q", value)
			}
			opts.Roles = roles
		case "--root":
			value, ok := nextValue(args, &i, "--root")
			if !ok {
				return opts, fmt.Errorf("--root requires a value")
			}
			opts.Root = value
		case "--force":
			opts.Force = true
		default:
			if strings.HasPrefix(args[i], "-") {
				return opts, fmt.Errorf("unknown flag: %s", args[i])
			}
			if opts.Name == "" {
				opts.Name = args[i]
				continue
			}
			roles, err := strconv.Atoi(args[i])
			if err != nil {
				return opts, fmt.Errorf("unexpected argument: %s", args[i])
			}
			opts.Roles = roles
		}
	}
	return opts, nil
}

func parseCreateRiffArgs(args []string) (riffs.CreateRiffOptions, error) {
	opts := riffs.CreateRiffOptions{Rounds: 10}
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--title":
			value, ok := nextValue(args, &i, "--title")
			if !ok {
				return opts, fmt.Errorf("--title requires a value")
			}
			opts.Title = value
		case "--prompt":
			value, ok := nextValue(args, &i, "--prompt")
			if !ok {
				return opts, fmt.Errorf("--prompt requires a value")
			}
			opts.Prompt = value
		case "--prompt-file":
			value, ok := nextValue(args, &i, "--prompt-file")
			if !ok {
				return opts, fmt.Errorf("--prompt-file requires a value")
			}
			opts.PromptFile = value
		case "--rounds", "-r":
			value, ok := nextValue(args, &i, "--rounds")
			if !ok {
				return opts, fmt.Errorf("--rounds requires a value")
			}
			rounds, err := strconv.Atoi(value)
			if err != nil {
				return opts, fmt.Errorf("invalid --rounds value %q", value)
			}
			opts.Rounds = rounds
		case "--support-folder", "--folder":
			flag := args[i]
			value, ok := nextValue(args, &i, "--support-folder")
			if !ok {
				return opts, fmt.Errorf("%s requires a value", flag)
			}
			opts.SupportFolders = append(opts.SupportFolders, value)
		case "--root":
			value, ok := nextValue(args, &i, "--root")
			if !ok {
				return opts, fmt.Errorf("--root requires a value")
			}
			opts.Root = value
		default:
			if strings.HasPrefix(args[i], "-") {
				return opts, fmt.Errorf("unknown flag: %s", args[i])
			}
			if opts.Template == "" {
				opts.Template = args[i]
				continue
			}
			return opts, fmt.Errorf("unexpected argument: %s", args[i])
		}
	}
	return opts, nil
}

func nextValue(args []string, index *int, flag string) (string, bool) {
	if *index+1 >= len(args) || strings.HasPrefix(args[*index+1], "-") {
		return "", false
	}
	*index = *index + 1
	return args[*index], true
}

func printUsage() {
	fmt.Println(`riffctl creates Riff role templates and app-visible riffs.

Usage:
  riffctl create template <name> [roles] [--roles N] [--root PATH] [--force]
  riffctl create <template> --title TITLE [--prompt TEXT | --prompt-file PATH] [--rounds N] [--support-folder PATH] [--root PATH]

Examples:
  riffctl create template architecture-debate --roles 3
  riffctl create template architecture-debate 3
  riffctl create architecture-debate --title "Architecture debate"

Output:
  ~/.riff/templates/architecture-debate/prompt.md
  ~/.riff/templates/architecture-debate/role-1.yaml
  ~/.riff/templates/architecture-debate/role-2.yaml
  ~/.riff/templates/architecture-debate/role-3.yaml
  ~/.riff/conversations/<id>/conversation.json

Workflow for another AI agent:
  1. Run: riffctl create template architecture-debate --roles 3
  2. Edit each role YAML with name, runtime, model, reasoning, emoji, and instructions.
  3. Edit prompt.md with the debate topic.
  4. Riff automatically applies ~/.riff/config/base_prompt.md when the riff runs.
  5. Create the app-visible riff from those files.
     riffctl create architecture-debate --title "Architecture debate"
  6. Open Riff. The new riff appears in the sidebar; click Start.`)
}
