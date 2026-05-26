package riffs

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCreateRiffFromTemplateWritesAppConversationLayout(t *testing.T) {
	root := t.TempDir()
	templatePath := filepath.Join(root, "templates", "architecture-debate")
	if err := os.MkdirAll(templatePath, 0755); err != nil {
		t.Fatalf("create template dir: %v", err)
	}
	writeFile(t, filepath.Join(templatePath, "role-1.yaml"), `name: Critic
runtime: claude
model: default
reasoning: ""
emoji: C
instructions: |
  Find the weakest assumption.
`)
	writeFile(t, filepath.Join(templatePath, "role-2.yaml"), `name: Researcher
runtime: codex
model: gpt-5.1
reasoning: high
emoji: R
instructions: |
  Bring evidence and citations.
`)
	promptPath := filepath.Join(t.TempDir(), "prompt.md")
	writeFile(t, promptPath, "Should we build the CLI?\n")

	result, err := CreateRiff(CreateRiffOptions{
		Root:       root,
		Template:   "architecture-debate",
		Title:      "Architecture debate",
		PromptFile: promptPath,
		Rounds:     10,
		SupportFolders: []string{
			"~/Workspaces/research",
		},
	})
	if err != nil {
		t.Fatalf("CreateRiff returned error: %v", err)
	}

	conversationPath := filepath.Join(result.Path, "conversation.json")
	data, err := os.ReadFile(conversationPath)
	if err != nil {
		t.Fatalf("read conversation.json: %v", err)
	}
	var conversation conversationJSON
	if err := json.Unmarshal(data, &conversation); err != nil {
		t.Fatalf("decode conversation.json: %v\n%s", err, string(data))
	}

	if conversation.Title != "Architecture debate" {
		t.Fatalf("title = %q", conversation.Title)
	}
	if conversation.Prompt != "Should we build the CLI?\n" {
		t.Fatalf("prompt = %q", conversation.Prompt)
	}
	if conversation.Status != "idle" {
		t.Fatalf("status = %q", conversation.Status)
	}
	if conversation.MaxRounds != 10 {
		t.Fatalf("maxRounds = %d", conversation.MaxRounds)
	}
	if len(conversation.Agents) != 2 {
		t.Fatalf("agents = %d, want 2", len(conversation.Agents))
	}
	if conversation.Agents[0].Name != "Critic" || conversation.Agents[0].Runtime != "claude" {
		t.Fatalf("first agent not loaded from YAML: %+v", conversation.Agents[0])
	}
	if conversation.Agents[1].Name != "Researcher" || conversation.Agents[1].Reasoning != "high" {
		t.Fatalf("second agent not loaded from YAML: %+v", conversation.Agents[1])
	}
	if len(conversation.SupportFolders) != 1 || !strings.HasSuffix(conversation.SupportFolders[0], "/Workspaces/research") {
		t.Fatalf("support folders = %#v", conversation.SupportFolders)
	}
	if _, err := os.Stat(filepath.Join(result.Path, "agents", conversation.Agents[0].ID, "agent.json")); err != nil {
		t.Fatalf("agent snapshot missing: %v", err)
	}
	if data, err := os.ReadFile(filepath.Join(result.Path, "transcript.jsonl")); err != nil || len(data) != 0 {
		t.Fatalf("transcript should exist and be empty, len=%d err=%v", len(data), err)
	}
	if _, err := os.Stat(filepath.Join(root, "config", "recent-conversations.json")); err != nil {
		t.Fatalf("recent conversations not written: %v", err)
	}
}

func TestCreateRiffDefaultsToTemplatePromptFile(t *testing.T) {
	root := t.TempDir()
	templatePath := filepath.Join(root, "templates", "default-prompt")
	if err := os.MkdirAll(templatePath, 0755); err != nil {
		t.Fatalf("create template dir: %v", err)
	}
	writeFile(t, filepath.Join(templatePath, "role-1.yaml"), `name: Critic
runtime: claude
model: default
instructions: |
  Argue clearly.
`)
	writeFile(t, filepath.Join(templatePath, "prompt.md"), "Use the template prompt by default.\n")

	result, err := CreateRiff(CreateRiffOptions{
		Root:     root,
		Template: "default-prompt",
		Title:    "Default prompt",
		Rounds:   1,
	})
	if err != nil {
		t.Fatalf("CreateRiff returned error: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(result.Path, "conversation.json"))
	if err != nil {
		t.Fatalf("read conversation.json: %v", err)
	}
	var conversation conversationJSON
	if err := json.Unmarshal(data, &conversation); err != nil {
		t.Fatalf("decode conversation.json: %v", err)
	}
	if conversation.Prompt != "Use the template prompt by default.\n" {
		t.Fatalf("prompt = %q", conversation.Prompt)
	}
}

func writeFile(t *testing.T, path string, contents string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(contents), 0644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}
