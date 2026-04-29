package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync/atomic"
	"time"

	"golang.org/x/sync/singleflight"
)

const (
	RequestPromptPresetModePrepend = "prepend"

	requestPromptPresetPlatformAll = "*"

	requestPromptPresetCacheTTL = 60 * time.Second
	requestPromptPresetErrorTTL = 5 * time.Second
)

type RequestPromptPresetRule struct {
	Platform     string `json:"platform"`
	ModelPattern string `json:"model_pattern"`
	Mode         string `json:"mode"`
	Text         string `json:"text"`
}

type cachedRequestPromptPresets struct {
	enabled   bool
	rules     []RequestPromptPresetRule
	expiresAt int64
}

var requestPromptPresetCache atomic.Value // *cachedRequestPromptPresets
var requestPromptPresetSF singleflight.Group

func parseRequestPromptPresetRules(raw string) ([]RequestPromptPresetRule, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}

	var rules []RequestPromptPresetRule
	if err := json.Unmarshal([]byte(raw), &rules); err != nil {
		return nil, fmt.Errorf("parse request prompt presets json: %w", err)
	}

	normalized := make([]RequestPromptPresetRule, 0, len(rules))
	for i, rule := range rules {
		platform, err := normalizeRequestPromptPresetPlatform(rule.Platform)
		if err != nil {
			return nil, fmt.Errorf("request prompt preset rule %d: %w", i+1, err)
		}
		modelPattern, err := normalizeRequestPromptPresetModelPattern(rule.ModelPattern)
		if err != nil {
			return nil, fmt.Errorf("request prompt preset rule %d: %w", i+1, err)
		}
		mode := strings.ToLower(strings.TrimSpace(rule.Mode))
		if mode == "" {
			mode = RequestPromptPresetModePrepend
		}
		if mode != RequestPromptPresetModePrepend {
			return nil, fmt.Errorf("request prompt preset rule %d: unsupported mode %q", i+1, rule.Mode)
		}
		text := strings.TrimSpace(rule.Text)
		if text == "" {
			return nil, fmt.Errorf("request prompt preset rule %d: text is required", i+1)
		}

		normalized = append(normalized, RequestPromptPresetRule{
			Platform:     platform,
			ModelPattern: modelPattern,
			Mode:         mode,
			Text:         text,
		})
	}

	return normalized, nil
}

func marshalRequestPromptPresetRules(raw string) (string, []RequestPromptPresetRule, error) {
	rules, err := parseRequestPromptPresetRules(raw)
	if err != nil {
		return "", nil, err
	}
	if len(rules) == 0 {
		return "", nil, nil
	}
	formatted, err := json.MarshalIndent(rules, "", "  ")
	if err != nil {
		return "", nil, fmt.Errorf("marshal request prompt presets json: %w", err)
	}
	return string(formatted), rules, nil
}

func normalizeRequestPromptPresetPlatform(raw string) (string, error) {
	platform := strings.ToLower(strings.TrimSpace(raw))
	switch platform {
	case "", requestPromptPresetPlatformAll:
		return requestPromptPresetPlatformAll, nil
	case PlatformOpenAI, PlatformAnthropic, PlatformGemini, PlatformAntigravity:
		return platform, nil
	default:
		return "", fmt.Errorf("unsupported platform %q", raw)
	}
}

func normalizeRequestPromptPresetModelPattern(raw string) (string, error) {
	pattern := strings.TrimSpace(raw)
	if pattern == "" {
		return "", fmt.Errorf("model_pattern is required")
	}
	if pattern == "*" {
		return pattern, nil
	}
	if strings.Count(pattern, "*") > 1 || (strings.Contains(pattern, "*") && !strings.HasSuffix(pattern, "*")) {
		return "", fmt.Errorf("model_pattern %q only supports exact match or a trailing * wildcard", raw)
	}
	return pattern, nil
}

func cloneRequestPromptPresetRules(src []RequestPromptPresetRule) []RequestPromptPresetRule {
	if len(src) == 0 {
		return nil
	}
	dst := make([]RequestPromptPresetRule, len(src))
	copy(dst, src)
	return dst
}

func requestPromptPresetMatches(rule RequestPromptPresetRule, platform, model string) bool {
	platform = strings.ToLower(strings.TrimSpace(platform))
	model = strings.ToLower(strings.TrimSpace(model))
	if platform == "" || model == "" {
		return false
	}

	rulePlatform := strings.ToLower(strings.TrimSpace(rule.Platform))
	if rulePlatform != "" && rulePlatform != requestPromptPresetPlatformAll && rulePlatform != platform {
		return false
	}

	pattern := strings.ToLower(strings.TrimSpace(rule.ModelPattern))
	switch {
	case pattern == "" || pattern == "*":
		return true
	case strings.HasSuffix(pattern, "*"):
		return strings.HasPrefix(model, strings.TrimSuffix(pattern, "*"))
	default:
		return model == pattern
	}
}

func buildRequestPromptPresetText(rules []RequestPromptPresetRule, platform, model string) string {
	if len(rules) == 0 {
		return ""
	}

	parts := make([]string, 0, len(rules))
	for _, rule := range rules {
		if !requestPromptPresetMatches(rule, platform, model) {
			continue
		}
		if text := strings.TrimSpace(rule.Text); text != "" {
			parts = append(parts, text)
		}
	}
	return strings.TrimSpace(strings.Join(parts, "\n\n"))
}

func prependRequestPromptText(existing, preset string) string {
	preset = strings.TrimSpace(preset)
	if preset == "" {
		return existing
	}

	trimmedExisting := strings.TrimSpace(existing)
	if trimmedExisting == "" {
		return preset
	}
	if trimmedExisting == preset || strings.HasPrefix(trimmedExisting, preset+"\n") {
		return existing
	}
	return preset + "\n\n" + strings.TrimRight(existing, " \t\r\n")
}

func applyRequestPromptPresetToOpenAIRequestBody(reqBody map[string]any, preset string) bool {
	if len(reqBody) == 0 {
		return false
	}
	existing, _ := reqBody["instructions"].(string)
	updated := prependRequestPromptText(existing, preset)
	if updated == existing {
		return false
	}
	reqBody["instructions"] = updated
	return true
}

func applyRequestPromptPresetsToOpenAIBodyBytes(body []byte, rules []RequestPromptPresetRule, model string) ([]byte, bool, error) {
	preset := buildRequestPromptPresetText(rules, PlatformOpenAI, model)
	if preset == "" || len(body) == 0 {
		return body, false, nil
	}

	var reqBody map[string]any
	if err := json.Unmarshal(body, &reqBody); err != nil {
		return body, false, nil
	}
	if !applyRequestPromptPresetToOpenAIRequestBody(reqBody, preset) {
		return body, false, nil
	}
	updated, err := json.Marshal(reqBody)
	if err != nil {
		return body, false, err
	}
	return updated, true, nil
}

func prependAnthropicSystemValue(system any, preset string) (any, bool) {
	preset = strings.TrimSpace(preset)
	if preset == "" {
		return system, false
	}

	switch v := normalizeSystemParam(system).(type) {
	case nil:
		return []any{map[string]any{"type": "text", "text": preset}}, true
	case string:
		updated := prependRequestPromptText(v, preset)
		if updated == v {
			return system, false
		}
		return updated, true
	case []any:
		if len(v) > 0 {
			if first, ok := v[0].(map[string]any); ok {
				if text, ok := first["text"].(string); ok {
					trimmed := strings.TrimSpace(text)
					if trimmed == preset || strings.HasPrefix(trimmed, preset+"\n") {
						return system, false
					}
				}
			}
		}
		updated := make([]any, 0, len(v)+1)
		updated = append(updated, map[string]any{"type": "text", "text": preset})
		updated = append(updated, v...)
		return updated, true
	default:
		return system, false
	}
}

func applyAnthropicSystemValueToBody(body []byte, system any) ([]byte, error) {
	raw, err := json.Marshal(system)
	if err != nil {
		return body, err
	}
	updated, ok := setJSONRawBytes(body, "system", raw)
	if !ok {
		return body, fmt.Errorf("set anthropic system")
	}
	return updated, nil
}

func prependRequestPromptPresetsToAnthropicBody(body []byte, system any, rules []RequestPromptPresetRule, platform, model string) ([]byte, any, bool, error) {
	preset := buildRequestPromptPresetText(rules, platform, model)
	if preset == "" || len(body) == 0 {
		return body, system, false, nil
	}

	updatedSystem, modified := prependAnthropicSystemValue(system, preset)
	if !modified {
		return body, system, false, nil
	}
	updatedBody, err := applyAnthropicSystemValueToBody(body, updatedSystem)
	if err != nil {
		return body, system, false, err
	}
	return updatedBody, updatedSystem, true, nil
}

func prependRequestPromptPresetsToAnthropicSystemRaw(raw json.RawMessage, rules []RequestPromptPresetRule, platform, model string) (json.RawMessage, bool, error) {
	preset := buildRequestPromptPresetText(rules, platform, model)
	if preset == "" {
		return raw, false, nil
	}

	var system any
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &system); err != nil {
			return raw, false, nil
		}
	}
	updatedSystem, modified := prependAnthropicSystemValue(system, preset)
	if !modified {
		return raw, false, nil
	}
	updatedRaw, err := json.Marshal(updatedSystem)
	if err != nil {
		return raw, false, err
	}
	return json.RawMessage(updatedRaw), true, nil
}

func applyRequestPromptPresetsToGeminiBody(body []byte, rules []RequestPromptPresetRule, model string) ([]byte, bool, error) {
	preset := buildRequestPromptPresetText(rules, PlatformGemini, model)
	if preset == "" || len(body) == 0 {
		return body, false, nil
	}

	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return body, false, nil
	}

	textPart := map[string]any{"text": preset}
	systemInstruction, _ := payload["systemInstruction"].(map[string]any)
	if systemInstruction == nil {
		payload["systemInstruction"] = map[string]any{
			"parts": []any{textPart},
		}
	} else {
		parts, _ := systemInstruction["parts"].([]any)
		if len(parts) > 0 {
			if first, ok := parts[0].(map[string]any); ok {
				if text, ok := first["text"].(string); ok {
					trimmed := strings.TrimSpace(text)
					if trimmed == preset || strings.HasPrefix(trimmed, preset+"\n") {
						return body, false, nil
					}
				}
			}
		}
		systemInstruction["parts"] = append([]any{textPart}, parts...)
		payload["systemInstruction"] = systemInstruction
	}

	updated, err := json.Marshal(payload)
	if err != nil {
		return body, false, err
	}
	return updated, true, nil
}

func (s *SettingService) BuildRequestPromptPresetText(ctx context.Context, platform, model string) string {
	enabled, rules := s.GetRequestPromptPresetRules(ctx)
	if !enabled {
		return ""
	}
	return buildRequestPromptPresetText(rules, platform, model)
}

func (s *SettingService) ApplyRequestPromptPresetsToOpenAIBody(ctx context.Context, body []byte, model string) ([]byte, bool, error) {
	enabled, rules := s.GetRequestPromptPresetRules(ctx)
	if !enabled {
		return body, false, nil
	}
	return applyRequestPromptPresetsToOpenAIBodyBytes(body, rules, model)
}

func (s *SettingService) PrependRequestPromptPresetsToAnthropicBody(ctx context.Context, body []byte, system any, platform, model string) ([]byte, any, bool, error) {
	enabled, rules := s.GetRequestPromptPresetRules(ctx)
	if !enabled {
		return body, system, false, nil
	}
	return prependRequestPromptPresetsToAnthropicBody(body, system, rules, platform, model)
}

func (s *SettingService) PrependRequestPromptPresetsToAnthropicBodyBytes(ctx context.Context, body []byte, platform, model string) ([]byte, bool, error) {
	enabled, rules := s.GetRequestPromptPresetRules(ctx)
	if !enabled || len(body) == 0 {
		return body, false, nil
	}

	var req struct {
		System json.RawMessage `json:"system"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		return body, false, nil
	}

	updatedSystem, modified, err := prependRequestPromptPresetsToAnthropicSystemRaw(req.System, rules, platform, model)
	if err != nil || !modified {
		return body, false, err
	}
	updatedBody, ok := setJSONRawBytes(body, "system", updatedSystem)
	if !ok {
		return body, false, fmt.Errorf("set anthropic system")
	}
	return updatedBody, true, nil
}

func (s *SettingService) PrependRequestPromptPresetsToAnthropicSystemRaw(ctx context.Context, raw json.RawMessage, platform, model string) (json.RawMessage, bool, error) {
	enabled, rules := s.GetRequestPromptPresetRules(ctx)
	if !enabled {
		return raw, false, nil
	}
	return prependRequestPromptPresetsToAnthropicSystemRaw(raw, rules, platform, model)
}

func (s *SettingService) ApplyRequestPromptPresetsToGeminiBody(ctx context.Context, body []byte, model string) ([]byte, bool, error) {
	enabled, rules := s.GetRequestPromptPresetRules(ctx)
	if !enabled {
		return body, false, nil
	}
	return applyRequestPromptPresetsToGeminiBody(body, rules, model)
}

func (s *SettingService) GetRequestPromptPresetRules(ctx context.Context) (bool, []RequestPromptPresetRule) {
	if s == nil || s.settingRepo == nil {
		return false, nil
	}

	now := time.Now().UnixNano()
	if cached, _ := requestPromptPresetCache.Load().(*cachedRequestPromptPresets); cached != nil && cached.expiresAt > now {
		return cached.enabled, cloneRequestPromptPresetRules(cached.rules)
	}

	value, _, _ := requestPromptPresetSF.Do("request_prompt_presets", func() (result any, err error) {
		defer func() {
			if recoverErr := recover(); recoverErr != nil {
				cached := &cachedRequestPromptPresets{expiresAt: time.Now().Add(requestPromptPresetErrorTTL).UnixNano()}
				requestPromptPresetCache.Store(cached)
				result = cached
				err = nil
			}
		}()
		settings, err := s.settingRepo.GetMultiple(ctx, []string{
			SettingKeyEnableRequestPromptPresets,
			SettingKeyRequestPromptPresetsJSON,
		})
		if err != nil {
			cached := &cachedRequestPromptPresets{expiresAt: time.Now().Add(requestPromptPresetErrorTTL).UnixNano()}
			requestPromptPresetCache.Store(cached)
			return cached, nil
		}

		enabled := settings[SettingKeyEnableRequestPromptPresets] == "true"
		rules, err := parseRequestPromptPresetRules(settings[SettingKeyRequestPromptPresetsJSON])
		if err != nil {
			enabled = false
			rules = nil
		}
		cached := &cachedRequestPromptPresets{
			enabled:   enabled,
			rules:     cloneRequestPromptPresetRules(rules),
			expiresAt: time.Now().Add(requestPromptPresetCacheTTL).UnixNano(),
		}
		requestPromptPresetCache.Store(cached)
		return cached, nil
	})

	cached, _ := value.(*cachedRequestPromptPresets)
	if cached == nil {
		return false, nil
	}
	return cached.enabled, cloneRequestPromptPresetRules(cached.rules)
}
