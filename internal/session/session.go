package session

import (
	"slices"
	"sync"
	"time"
)

type SubjectState struct {
	Connected       bool
	Name            string
	ScenariosDone   []string
	CurrentScenario string
	BytesReceived   int64
	LastSeen        time.Time
}

type State struct {
	mu        sync.RWMutex
	subjects  map[string]*SubjectState
	started   bool
	startedAt time.Time
}

func New() *State {
	return &State{
		subjects: make(map[string]*SubjectState),
	}
}

func (s *State) Connect(subjectID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.subjects[subjectID]; !ok {
		s.subjects[subjectID] = &SubjectState{
			ScenariosDone: []string{},
		}
	}
	s.subjects[subjectID].Connected = true
	s.subjects[subjectID].LastSeen = time.Now()
}

func (s *State) SetName(subjectID, name string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.subjects[subjectID]; !ok {
		s.subjects[subjectID] = &SubjectState{
			ScenariosDone: []string{},
		}
	}
	s.subjects[subjectID].Name = name
}

func (s *State) SetCurrentScenario(subjectID, scenario string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if sub, ok := s.subjects[subjectID]; ok {
		sub.CurrentScenario = scenario
	}
}

func (s *State) Disconnect(subjectID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if sub, ok := s.subjects[subjectID]; ok {
		sub.Connected = false
		sub.LastSeen = time.Now()
	}
}

func (s *State) RecordUpload(subjectID, scenario string, bytes int64) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.subjects[subjectID]; !ok {
		s.subjects[subjectID] = &SubjectState{
			ScenariosDone: []string{},
		}
	}

	sub := s.subjects[subjectID]
	sub.BytesReceived += bytes
	sub.LastSeen = time.Now()

	// Don't add to ScenariosDone here - it's handled by CompleteScenario
}

func (s *State) CompleteScenario(subjectID, scenario string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if sub, ok := s.subjects[subjectID]; ok {
		if !slices.Contains(sub.ScenariosDone, scenario) {
			sub.ScenariosDone = append(sub.ScenariosDone, scenario)
		}
		sub.CurrentScenario = ""
	}
}

func (s *State) GetAll() map[string]SubjectState {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make(map[string]SubjectState)
	for id, sub := range s.subjects {
		result[id] = SubjectState{
			Connected:       sub.Connected,
			Name:            sub.Name,
			ScenariosDone:   append([]string{}, sub.ScenariosDone...),
			CurrentScenario: sub.CurrentScenario,
			BytesReceived:   sub.BytesReceived,
			LastSeen:        sub.LastSeen,
		}
	}
	return result
}

func (s *State) GetSubject(subjectID string) (SubjectState, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sub, ok := s.subjects[subjectID]
	if !ok {
		return SubjectState{}, false
	}

	return SubjectState{
		Connected:       sub.Connected,
		Name:            sub.Name,
		ScenariosDone:   append([]string{}, sub.ScenariosDone...),
		CurrentScenario: sub.CurrentScenario,
		BytesReceived:   sub.BytesReceived,
		LastSeen:        sub.LastSeen,
	}, true
}

func (s *State) ConnectedCount() int {
	s.mu.RLock()
	defer s.mu.RUnlock()

	count := 0
	for _, sub := range s.subjects {
		if sub.Connected {
			count++
		}
	}
	return count
}

func (s *State) IsStarted() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.started
}

func (s *State) MarkStarted() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.started = true
	s.startedAt = time.Now()
}

func (s *State) StartedAt() time.Time {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.startedAt
}
