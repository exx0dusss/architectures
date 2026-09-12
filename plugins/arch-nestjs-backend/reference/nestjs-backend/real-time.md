# Real-Time (WebSocket)

## Architecture

```
Domain Event → EventEmitter2 → Redis Pub/Sub → WebSocket Gateway → Client
```

Events flow one direction: backend emits, clients subscribe. Never update frontend state directly from socket data — use TanStack Query invalidation.

## WebSocket Gateway

```typescript
@WebSocketGateway({ namespace: '/ws', cors: true })
export class EventsGateway implements OnGatewayConnection {
  async handleConnection(client: Socket) {
    const token = client.handshake.auth?.token;
    const user = await this.verifyJwt(token);
    if (!user) { client.disconnect(); return; }
    client.data.user = user;
  }

  @SubscribeMessage('subscribe')
  handleSubscribe(client: Socket, channels: string[]) {
    const allowed = filterByRole(channels, client.data.user.role);
    allowed.forEach(ch => client.join(ch));
  }
}
```

## Redis Pub/Sub Bridge

Domain events publish to Redis, gateway subscribes and forwards to rooms:

```typescript
@OnEvent('order.placed', { async: true })
async handleOrderPlaced(payload: OrderPlacedEvent) {
  await this.redis.publish('orders', JSON.stringify({
    type: 'order.placed',
    data: payload,
  }));
}
```

## Role-based channels

| Channel | Roles | Events |
|---------|-------|--------|
| `orders` | admin, manager | order.placed, order.updated, payment.completed |
| `inventory` | admin, manager | stock.low, stock.updated |
| `products` | admin, manager | product.updated, price.changed |
| `chat` | admin, support | message.new, conversation.created |
| `imports` | admin, manager | import.completed, import.failed |
| `notifications` | all authenticated | notification.new |

## Chat-specific patterns

```typescript
// Join conversation rooms
@SubscribeMessage('chat:subscribe')
handleChatSubscribe(client: Socket, conversationIds: string[]) {
  conversationIds.forEach(id => client.join(`chat:${id}`));
}

// Typing indicators
@SubscribeMessage('chat:typing')
handleTyping(client: Socket, { conversationId }: { conversationId: string }) {
  client.to(`chat:${conversationId}`).emit('chat:typing.start', {
    userId: client.data.user.id,
    conversationId,
  });
}

// Presence (online/away/offline)
@SubscribeMessage('chat:presence')
handlePresence(client: Socket, status: 'online' | 'away' | 'offline') {
  client.broadcast.emit('chat:presence.update', {
    userId: client.data.user.id,
    status,
  });
}
```

## Frontend integration

```typescript
// hooks/use-realtime.ts
wsManager.subscribe('orders', () => {
  queryClient.invalidateQueries({ queryKey: ['orders'] });
});
```

**Rule:** Socket is the notification channel, Query is the data channel. Socket events trigger `invalidateQueries()`. Never set query cache directly from socket data.
