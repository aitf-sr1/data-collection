package broadcast

import (
	"sync"
)

type Event struct {
	Type      string `json:"type"`
	Timestamp int64  `json:"timestamp"`
}

type Broadcaster struct {
	mu      sync.RWMutex
	clients map[string]chan Event
}

func New() *Broadcaster {
	return &Broadcaster{
		clients: make(map[string]chan Event),
	}
}

func (b *Broadcaster) Subscribe(id string) <-chan Event {
	b.mu.Lock()
	defer b.mu.Unlock()

	ch := make(chan Event, 8)
	b.clients[id] = ch
	return ch
}

func (b *Broadcaster) Unsubscribe(id string) {
	b.mu.Lock()
	defer b.mu.Unlock()

	if ch, ok := b.clients[id]; ok {
		close(ch)
		delete(b.clients, id)
	}
}

func (b *Broadcaster) Broadcast(e Event) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	for _, ch := range b.clients {
		select {
		case ch <- e:
		default:
		}
	}
}

func (b *Broadcaster) Count() int {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return len(b.clients)
}
