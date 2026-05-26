package riffs

import (
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

type PublishDraftResult struct {
	ID   string
	Path string
}

type PublishDraftOptions struct {
	Root string
	Name string
}

type roleYAML struct {
	Name       string `yaml:"name"`
	Runtime    string `yaml:"runtime"`
	Model      string `yaml:"model"`
	Reasoning  string `yaml:"reasoning"`
	RolePrompt string `yaml:"role_prompt"`
}

type agentJSON struct {
	Emoji        string `json:"emoji,omitempty"`
	ID           string `json:"id"`
	Instructions string `json:"instructions"`
	Model        string `json:"model"`
	Name         string `json:"name"`
	Reasoning    string `json:"reasoning,omitempty"`
	Role         string `json:"role"`
	Runtime      string `json:"runtime"`
}

type conversationJSON struct {
	Agents         []agentJSON `json:"agents"`
	CreatedAt      string      `json:"createdAt"`
	ID             string      `json:"id"`
	MaxRounds      int         `json:"maxRounds"`
	Prompt         string      `json:"prompt"`
	Status         string      `json:"status"`
	SupportFolders []string    `json:"supportFolders"`
	Title          string      `json:"title"`
}

type conversationLocationJSON struct {
	ID  string `json:"id"`
	URL string `json:"url"`
}

type draftRiffYAML struct {
	Title          string          `yaml:"title"`
	Prompt         string          `yaml:"prompt"`
	Rounds         int             `yaml:"rounds"`
	SupportFolders []string        `yaml:"support_folders"`
	Agents         []draftAgentRef `yaml:"agents"`
}

type draftAgentRef struct {
	RoleFile string `yaml:"role_file"`
}

func PublishDraft(opts PublishDraftOptions) (PublishDraftResult, error) {
	root, err := rootPath(opts.Root)
	if err != nil {
		return PublishDraftResult{}, err
	}
	draftPath, err := resolveDraftPath(root, opts.Name)
	if err != nil {
		return PublishDraftResult{}, err
	}
	draft, err := readDraftRiff(draftPath)
	if err != nil {
		return PublishDraftResult{}, err
	}
	prompt := ensurePrompt(draft.Prompt)
	if strings.TrimSpace(prompt) == "" {
		return PublishDraftResult{}, fmt.Errorf("draft prompt is required in %s", filepath.Join(draftPath, "riff.yaml"))
	}
	agents, err := readDraftAgents(draftPath, draft.Agents)
	if err != nil {
		return PublishDraftResult{}, err
	}
	if len(agents) == 0 {
		return PublishDraftResult{}, fmt.Errorf("draft has no agent YAML files: %s", draftPath)
	}
	conversationID, err := newUUID()
	if err != nil {
		return PublishDraftResult{}, err
	}
	supportFolders, err := fileURLs(draft.SupportFolders)
	if err != nil {
		return PublishDraftResult{}, err
	}
	conversationPath := filepath.Join(root, "conversations", conversationID)
	conversation := conversationJSON{
		Agents:         agents,
		CreatedAt:      time.Now().UTC().Format(time.RFC3339),
		ID:             conversationID,
		MaxRounds:      roundsOrDefault(draft.Rounds),
		Prompt:         prompt,
		Status:         "idle",
		SupportFolders: supportFolders,
		Title:          titleOrDefault(draft.Title, opts.Name),
	}
	if err := writeConversation(conversationPath, conversation); err != nil {
		return PublishDraftResult{}, err
	}
	if err := rememberConversation(root, conversationID, conversationPath); err != nil {
		return PublishDraftResult{}, err
	}
	return PublishDraftResult{ID: conversationID, Path: conversationPath}, nil
}

func readDraftRiff(draftPath string) (draftRiffYAML, error) {
	data, err := os.ReadFile(filepath.Join(draftPath, "riff.yaml"))
	if err != nil {
		return draftRiffYAML{}, err
	}
	var draft draftRiffYAML
	if err := yaml.Unmarshal(data, &draft); err != nil {
		return draftRiffYAML{}, err
	}
	return draft, nil
}

func readDraftAgents(draftPath string, refs []draftAgentRef) ([]agentJSON, error) {
	files, err := draftAgentFiles(draftPath, refs)
	if err != nil {
		return nil, err
	}
	agents := make([]agentJSON, 0, len(files))
	for i, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return nil, err
		}
		var role roleYAML
		if err := yaml.Unmarshal(data, &role); err != nil {
			return nil, fmt.Errorf("parse %s: %w", file, err)
		}
		agent, err := agentFromRole(role, i+1, file)
		if err != nil {
			return nil, err
		}
		agents = append(agents, agent)
	}
	return agents, nil
}

func draftAgentFiles(draftPath string, refs []draftAgentRef) ([]string, error) {
	if len(refs) == 0 {
		files, err := filepath.Glob(filepath.Join(draftPath, "agents", "role-*.yaml"))
		if err != nil {
			return nil, err
		}
		sort.Slice(files, func(i, j int) bool {
			return roleFileIndex(files[i]) < roleFileIndex(files[j])
		})
		return files, nil
	}
	files := make([]string, 0, len(refs))
	for _, ref := range refs {
		path, err := draftRelativePath(draftPath, ref.RoleFile)
		if err != nil {
			return nil, err
		}
		files = append(files, path)
	}
	return files, nil
}

func draftRelativePath(draftPath string, relative string) (string, error) {
	cleaned := filepath.Clean(strings.TrimSpace(relative))
	if cleaned == "." || cleaned == "" {
		return "", errors.New("draft file path is required")
	}
	if filepath.IsAbs(cleaned) || strings.HasPrefix(cleaned, "..") {
		return "", fmt.Errorf("invalid draft-relative path: %s", relative)
	}
	return filepath.Join(draftPath, cleaned), nil
}

func ensurePrompt(prompt string) string {
	if strings.TrimSpace(prompt) == "" || strings.HasSuffix(prompt, "\n") {
		return prompt
	}
	return prompt + "\n"
}

func agentFromRole(role roleYAML, index int, file string) (agentJSON, error) {
	name := strings.TrimSpace(role.Name)
	if name == "" {
		name = "Role " + strconv.Itoa(index)
	}
	instructions := strings.TrimSpace(role.RolePrompt)
	if instructions == "" {
		return agentJSON{}, fmt.Errorf("%s: role_prompt is required", file)
	}
	runtime := strings.TrimSpace(role.Runtime)
	if runtime == "" {
		runtime = "claude"
	}
	if runtime != "claude" && runtime != "codex" {
		return agentJSON{}, fmt.Errorf("%s: runtime must be claude or codex", file)
	}
	model := strings.TrimSpace(role.Model)
	if model == "" {
		model = "default"
	}
	id, err := newUUID()
	if err != nil {
		return agentJSON{}, err
	}
	return agentJSON{
		ID:           id,
		Instructions: instructions,
		Model:        model,
		Name:         name,
		Reasoning:    strings.TrimSpace(role.Reasoning),
		Role:         name,
		Runtime:      runtime,
	}, nil
}

func writeConversation(path string, conversation conversationJSON) error {
	if err := os.MkdirAll(filepath.Join(path, "files"), 0755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(path, "agents"), 0755); err != nil {
		return err
	}
	for _, agent := range conversation.Agents {
		agentPath := filepath.Join(path, "agents", agent.ID)
		if err := os.MkdirAll(filepath.Join(agentPath, "cwd"), 0755); err != nil {
			return err
		}
		if err := writeJSON(filepath.Join(agentPath, "agent.json"), agent); err != nil {
			return err
		}
	}
	if err := os.WriteFile(filepath.Join(path, "transcript.jsonl"), nil, 0644); err != nil {
		return err
	}
	return writeJSON(filepath.Join(path, "conversation.json"), conversation)
}

func rememberConversation(root string, id string, conversationPath string) error {
	configPath := filepath.Join(root, "config")
	recentPath := filepath.Join(configPath, "recent-conversations.json")
	if err := os.MkdirAll(configPath, 0755); err != nil {
		return err
	}
	var locations []conversationLocationJSON
	if data, err := os.ReadFile(recentPath); err == nil && len(strings.TrimSpace(string(data))) > 0 {
		if err := json.Unmarshal(data, &locations); err != nil {
			return err
		}
	} else if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	location := conversationLocationJSON{ID: id, URL: fileURL(conversationPath, true)}
	filtered := make([]conversationLocationJSON, 0, len(locations)+1)
	filtered = append(filtered, location)
	for _, existing := range locations {
		if existing.ID != id && existing.URL != location.URL {
			filtered = append(filtered, existing)
		}
	}
	return writeJSON(recentPath, filtered)
}

func writeJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

func resolveDraftPath(root string, draft string) (string, error) {
	draft = strings.TrimSpace(draft)
	if draft == "" {
		return "", errors.New("draft name or path is required")
	}
	expanded := expandHome(draft)
	if filepath.IsAbs(expanded) || strings.HasPrefix(draft, ".") {
		if info, err := os.Stat(expanded); err == nil && info.IsDir() {
			return expanded, nil
		} else if err != nil {
			return "", err
		}
	}
	path := filepath.Join(root, "drafts", slug(draft))
	if info, err := os.Stat(path); err == nil && info.IsDir() {
		return path, nil
	} else if err != nil {
		return "", err
	}
	return path, nil
}

func rootPath(root string) (string, error) {
	if strings.TrimSpace(root) != "" {
		return expandHome(root), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".riff"), nil
}

func fileURLs(paths []string) ([]string, error) {
	urls := make([]string, 0, len(paths))
	for _, path := range paths {
		cleaned := strings.TrimSpace(path)
		if cleaned == "" {
			continue
		}
		expanded := expandHome(cleaned)
		absolute, err := filepath.Abs(expanded)
		if err != nil {
			return nil, err
		}
		urls = append(urls, fileURL(absolute, false))
	}
	return urls, nil
}

func fileURL(path string, trailingSlash bool) string {
	u := url.URL{Scheme: "file", Path: path}
	text := u.String()
	if trailingSlash && !strings.HasSuffix(text, "/") {
		text += "/"
	}
	return text
}

func roundsOrDefault(rounds int) int {
	if rounds < 1 {
		return 10
	}
	return rounds
}

func titleOrDefault(title string, template string) string {
	cleaned := strings.TrimSpace(title)
	if cleaned != "" {
		return cleaned
	}
	name := filepath.Base(strings.TrimSpace(template))
	words := strings.Fields(strings.ReplaceAll(slug(name), "-", " "))
	if len(words) == 0 {
		return "Untitled Riff"
	}
	for i, word := range words {
		words[i] = strings.ToUpper(word[:1]) + word[1:]
	}
	return strings.Join(words, " ")
}

var roleNumber = regexp.MustCompile(`role-(\d+)\.ya?ml$`)

func roleFileIndex(path string) int {
	matches := roleNumber.FindStringSubmatch(filepath.Base(path))
	if len(matches) != 2 {
		return 1_000_000
	}
	value, err := strconv.Atoi(matches[1])
	if err != nil {
		return 1_000_000
	}
	return value
}

var nonSlugChars = regexp.MustCompile(`[^a-z0-9]+`)

func slug(value string) string {
	lowered := strings.ToLower(strings.TrimSpace(value))
	slugged := nonSlugChars.ReplaceAllString(lowered, "-")
	slugged = strings.Trim(slugged, "-")
	if slugged == "" {
		return "agent"
	}
	return slugged
}

func expandHome(path string) string {
	if path == "~" {
		home, err := os.UserHomeDir()
		if err == nil {
			return home
		}
	}
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err == nil {
			return filepath.Join(home, strings.TrimPrefix(path, "~/"))
		}
	}
	return path
}

func newUUID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf(
		"%08x-%04x-%04x-%04x-%012x",
		b[0:4],
		b[4:6],
		b[6:8],
		b[8:10],
		b[10:16],
	), nil
}
