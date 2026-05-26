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

type CreateRiffOptions struct {
	Root           string
	Template       string
	Title          string
	Prompt         string
	PromptFile     string
	Rounds         int
	SupportFolders []string
}

type CreateRiffResult struct {
	ID   string
	Path string
}

type roleYAML struct {
	Name         string `yaml:"name"`
	Runtime      string `yaml:"runtime"`
	Model        string `yaml:"model"`
	Reasoning    string `yaml:"reasoning"`
	Emoji        string `yaml:"emoji"`
	Instructions string `yaml:"instructions"`
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

func CreateRiff(opts CreateRiffOptions) (CreateRiffResult, error) {
	root, err := rootPath(opts.Root)
	if err != nil {
		return CreateRiffResult{}, err
	}
	templatePath, err := resolveTemplatePath(root, opts.Template)
	if err != nil {
		return CreateRiffResult{}, err
	}
	prompt, err := readPrompt(opts)
	if err != nil {
		return CreateRiffResult{}, err
	}
	agents, err := readAgents(templatePath)
	if err != nil {
		return CreateRiffResult{}, err
	}
	if len(agents) == 0 {
		return CreateRiffResult{}, fmt.Errorf("template has no role YAML files: %s", templatePath)
	}
	conversationID, err := newUUID()
	if err != nil {
		return CreateRiffResult{}, err
	}
	supportFolders, err := fileURLs(opts.SupportFolders)
	if err != nil {
		return CreateRiffResult{}, err
	}
	conversationPath := filepath.Join(root, "conversations", conversationID)
	conversation := conversationJSON{
		Agents:         agents,
		CreatedAt:      time.Now().UTC().Format(time.RFC3339),
		ID:             conversationID,
		MaxRounds:      roundsOrDefault(opts.Rounds),
		Prompt:         prompt,
		Status:         "idle",
		SupportFolders: supportFolders,
		Title:          titleOrDefault(opts.Title, opts.Template),
	}
	if err := writeConversation(conversationPath, conversation); err != nil {
		return CreateRiffResult{}, err
	}
	if err := rememberConversation(root, conversationID, conversationPath); err != nil {
		return CreateRiffResult{}, err
	}
	return CreateRiffResult{ID: conversationID, Path: conversationPath}, nil
}

func readPrompt(opts CreateRiffOptions) (string, error) {
	if strings.TrimSpace(opts.Prompt) != "" && strings.TrimSpace(opts.PromptFile) != "" {
		return "", errors.New("use --prompt or --prompt-file, not both")
	}
	if strings.TrimSpace(opts.PromptFile) != "" {
		data, err := os.ReadFile(expandHome(opts.PromptFile))
		if err != nil {
			return "", err
		}
		prompt := string(data)
		if strings.TrimSpace(prompt) == "" {
			return "", errors.New("prompt file is empty")
		}
		return prompt, nil
	}
	if strings.TrimSpace(opts.Prompt) == "" {
		return "", errors.New("prompt is required; pass --prompt or --prompt-file")
	}
	return opts.Prompt, nil
}

func readAgents(templatePath string) ([]agentJSON, error) {
	files, err := filepath.Glob(filepath.Join(templatePath, "role-*.yaml"))
	if err != nil {
		return nil, err
	}
	sort.Slice(files, func(i, j int) bool {
		return roleFileIndex(files[i]) < roleFileIndex(files[j])
	})
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

func agentFromRole(role roleYAML, index int, file string) (agentJSON, error) {
	name := strings.TrimSpace(role.Name)
	if name == "" {
		name = "Role " + strconv.Itoa(index)
	}
	instructions := strings.TrimSpace(role.Instructions)
	if instructions == "" {
		return agentJSON{}, fmt.Errorf("%s: instructions are required", file)
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
		Emoji:        strings.TrimSpace(role.Emoji),
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

func resolveTemplatePath(root string, template string) (string, error) {
	template = strings.TrimSpace(template)
	if template == "" {
		return "", errors.New("template name or path is required")
	}
	expanded := expandHome(template)
	if filepath.IsAbs(expanded) || strings.HasPrefix(template, ".") {
		if info, err := os.Stat(expanded); err == nil && info.IsDir() {
			return expanded, nil
		} else if err != nil {
			return "", err
		}
	}
	path := filepath.Join(root, "templates", slug(template))
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
