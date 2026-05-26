package riffs

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPublishDraftWritesAppConversationLayout(t *testing.T) {
	root := t.TempDir()
	draftPath := filepath.Join(root, "drafts", "architecture-debate")
	if err := os.MkdirAll(filepath.Join(draftPath, "agents"), 0755); err != nil {
		t.Fatalf("create draft dir: %v", err)
	}
	writeFile(t, filepath.Join(draftPath, "riff.yaml"), `title: Architecture debate
prompt: |
  Should we build the CLI?
rounds: 10
support_folders:
  - ~/Workspaces/research
agents:
  - role_file: agents/role-1.yaml
  - role_file: agents/role-2.yaml
`)
	writeFile(t, filepath.Join(draftPath, "agents", "role-1.yaml"), `name: Critic
runtime: claude
model: default
reasoning: ""
role_prompt: |
  Find the weakest assumption.
`)
	writeFile(t, filepath.Join(draftPath, "agents", "role-2.yaml"), `name: Researcher
runtime: codex
model: gpt-5.1
reasoning: high
role_prompt: |
  Bring evidence and citations.
`)

	result, err := PublishDraft(PublishDraftOptions{Root: root, Name: "architecture-debate"})
	if err != nil {
		t.Fatalf("PublishDraft returned error: %v", err)
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
	if conversation.Agents[0].Instructions != "Find the weakest assumption." {
		t.Fatalf("first agent role prompt not loaded from YAML: %+v", conversation.Agents[0])
	}
	if conversation.Agents[0].Emoji != "" {
		t.Fatalf("first agent emoji should not be loaded from YAML: %+v", conversation.Agents[0])
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

func TestPublishDraftRequiresInlinePrompt(t *testing.T) {
	root := t.TempDir()
	draftPath := filepath.Join(root, "drafts", "missing-prompt")
	if err := os.MkdirAll(filepath.Join(draftPath, "agents"), 0755); err != nil {
		t.Fatalf("create draft dir: %v", err)
	}
	writeFile(t, filepath.Join(draftPath, "riff.yaml"), `title: Missing prompt
rounds: 1
agents:
  - role_file: agents/role-1.yaml
`)
	writeFile(t, filepath.Join(draftPath, "agents", "role-1.yaml"), `name: Critic
runtime: claude
model: default
role_prompt: |
  Argue clearly.
`)

	if _, err := PublishDraft(PublishDraftOptions{Root: root, Name: "missing-prompt"}); err == nil {
		t.Fatal("PublishDraft returned nil error for missing inline prompt")
	}
}

func writeFile(t *testing.T, path string, contents string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(contents), 0644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}
